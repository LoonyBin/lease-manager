# frozen_string_literal: true

module Settlements
  # The unwind + re-infer half of settlement. Allocation in this app is stored,
  # not inferred: an instrument's ledger footprint is one +initial+ entry plus
  # the paired +settlement+ entries that apply it. This class removes that
  # footprint and re-derives the affected lease from scratch, leaving it exactly
  # as if the de-allocated instrument had never been recorded.
  #
  # +deallocate+ (interactive, one payment) and +readjust+ (bulk repair of a
  # whole lease) share a single re-inference path, +reinfer_lease+; the only
  # differences are whether one instrument is excluded (+except:+) and whether
  # removals are versioned (+audited:+).
  #
  # transaction_id instability: re-inference clears *every* settlement on the
  # lease and re-creates them with fresh transaction_ids, so a settlement's
  # transaction_id is not stable across a de-allocation. Nothing persists a
  # reference to it — the only consumers are render-time joins on the payment
  # and invoice show pages — so this is safe. See #194.
  class Deallocation
    class << self
      # Remove a payment's full ledger footprint from its lease and re-infer the
      # invoices/credits it had touched. The payment keeps its own status; only
      # its entries and balance are cleared, so it can never report unapplied
      # credit again. Atomic: nothing is observable if any step raises.
      def deallocate(payment)
        lease = payment.lease
        old_balance = lease.entries.sum(:amount)
        footprint = nil

        ActiveRecord::Base.transaction do
          footprint = remove_footprint(payment)
          reinfer_lease(lease, except: payment, audited: true)
          lease.recalculate_cached_balance!
        end

        footprint.merge(payment: payment, old_balance: old_balance, new_balance: lease.entries.sum(:amount))
      end

      # The inverse of +deallocate+: re-establish a payment's initial entry (on
      # its *current* lease, correcting a stranded lease_id) and re-settle it.
      # Unlike +deallocate+ this re-establishes the payment's status. #193 drives
      # cross-lease re-assignment through +transaction { deallocate(p);
      # p.update!(lease: dest); reallocate(p) }+ — see the transaction note below.
      def reallocate(payment)
        ActiveRecord::Base.transaction do
          rebuild_initial_entry(payment)
          payment.recalculate_balance!
          SettlementService.auto_settle(payment)
          payment.lease.recalculate_cached_balance!
        end

        payment
      end

      # Bulk repair: re-infer a whole lease, cleaning up settlement churn and any
      # orphaned initial entries left behind by past rejections. Unversioned
      # (+audited: false+) — this is a maintenance sweep, not an interactive edit.
      def readjust(lease)
        old_balance = lease.entries.sum(:amount)
        counts = nil

        ActiveRecord::Base.transaction do
          counts = reinfer_lease(lease, audited: false)
        end

        counts.merge(old_balance: old_balance, new_balance: lease.entries.sum(:amount))
      end

      # deallocate and readjust both funnel through here — the single re-inference
      # path. +except:+ omits one instrument from every sweep (recalculate,
      # resettle-credits, and the debit list reached via
      # SettlementService.auto_settle); +audited:+ routes settlement removal
      # through destroy_all (versioned) instead of delete_all. Public by design:
      # it is the load-bearing operation and the exclusion-routing spec drives it
      # directly rather than reaching past the public surface.
      def reinfer_lease(lease, except: nil, audited: false)
        settlement_count = clear_settlements(lease, audited: audited)
        orphan_count = clear_rejected_initials(lease)
        recalculate_balances(lease, except: except)
        credit_count = resettle_credits(lease, except: except)

        { settlement_count: settlement_count, orphan_count: orphan_count, credit_count: credit_count }
      end

      private

      # Re-establish a payment's initial entry on its current lease, correcting a
      # stranded lease_id. first_or_initialize compares amount only, so the lease
      # and transaction_id are set explicitly.
      def rebuild_initial_entry(payment)
        payment.entries.initial.first_or_initialize.tap do |entry|
          entry.lease = payment.lease
          entry.transaction_id = nil
          entry.amount = payment.signed_amount
        end.save!
      end

      # Destroys both sides of every settlement transaction the payment is part
      # of, plus its own initial entry, then zeroes its balance (status
      # untouched). destroy_all rather than delete_all so PaperTrail records the
      # removal. Both-sides removal is load-bearing: dependent: :destroy on
      # Payment#entries reaches only the payment's own rows, never the paired
      # counterpart rows (#196 relies on this too).
      def remove_footprint(payment)
        transaction_ids = payment.entries.settlements.pluck(:transaction_id).uniq
        counterparts = counterpart_instruments(payment, transaction_ids)

        entries_removed = Entry.for_transaction(transaction_ids).destroy_all.size
        entries_removed += payment.entries.initial.destroy_all.size
        payment.update_column(:balance, 0) # rubocop:disable Rails/SkipsModelValidations -- skip callbacks; status preserved

        { counterparts: counterparts, entries_removed: entries_removed,
          transactions_removed: transaction_ids.size }
      end

      # The invoices/credits/refunds a payment had settled, captured before
      # removal so callers get a stable pre-recompute identity list.
      def counterpart_instruments(payment, transaction_ids)
        return [] if transaction_ids.empty?

        Entry.for_transaction(transaction_ids)
             .where.not(instrument: payment)
             .includes(:instrument)
             .map(&:instrument)
             .uniq
      end

      def clear_settlements(lease, audited: false)
        settlements = lease.entries.settlements
        return settlements.delete_all unless audited

        settlements.destroy_all.size
      end

      # Repairs leases corrupted by a past rejection: a rejected payment's
      # +initial+ entry survives readjust's settlement wipe and skews the lease
      # statement forever. Remove those orphans and zero the stale balance. The
      # de-allocated payment's own initial is already gone via remove_footprint,
      # so this only touches *other* rejected payments on the lease.
      def clear_rejected_initials(lease)
        count = 0
        lease.payments.rejected.find_each do |payment|
          count += payment.entries.initial.destroy_all.size
          payment.update_column(:balance, 0) unless payment.balance.zero? # rubocop:disable Rails/SkipsModelValidations
        end
        count
      end

      def recalculate_balances(lease, except: nil)
        lease.invoices.finalized_or_later.find_each(&:recalculate_balance!)
        payments = lease.payments.confirmed_or_later
        payments = payments.where.not(id: except.id) if except
        payments.find_each(&:recalculate_balance!)
      end

      def resettle_credits(lease, except: nil)
        credits = chronological_credits(lease, except: except)
        credits.each { |credit| SettlementService.auto_settle(credit, except: except) }
        credits.size
      end

      def chronological_credits(lease, except: nil)
        payments = lease.payments.payment.unsettled.to_a
        credit_notes = lease.invoices.credit_note.unsettled.to_a
        credits = (payments + credit_notes).sort_by { |i| [i.date, i.created_at] }
        except ? credits.reject { |credit| credit == except } : credits
      end
    end
  end
end
