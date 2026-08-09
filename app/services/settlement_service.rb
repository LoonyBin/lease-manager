# frozen_string_literal: true

# The settle half of settlement: turning unallocated credits and debits into
# paired ledger entries. The unwind half — removing a footprint and re-inferring
# a lease — lives in Settlements::Deallocation, which drives the credit sweep
# back through +auto_settle+ here. The +except:+ kwarg lets that re-inference
# skip a single instrument (the one being de-allocated) as it settles the rest.
class SettlementService
  class << self
    def auto_settle(instrument, except: nil)
      return unless instrument.balance.abs.positive?

      if instrument.credit?
        settle_credit(instrument, except: except)
      else
        settle_debit(instrument)
      end
    end

    def settle(credit:, debit:, amount:)
      validate_settlement!(credit: credit, debit: debit, amount: amount)

      transaction_id = SecureRandom.uuid

      ActiveRecord::Base.transaction do
        create_entry(instrument: credit, amount: amount, transaction_id: transaction_id)
        create_entry(instrument: debit, amount: -amount, transaction_id: transaction_id)
        credit.recalculate_balance!
        debit.recalculate_balance!
      end

      transaction_id
    end

    # The unwind family lives in Settlements::Deallocation; these delegators keep
    # SettlementService the single entry point callers already know.
    # rubocop:disable Rails/Delegate -- delegating class methods to a sibling service, not an association
    def deallocate(payment) = Settlements::Deallocation.deallocate(payment)
    def reallocate(payment) = Settlements::Deallocation.reallocate(payment)
    def readjust(lease) = Settlements::Deallocation.readjust(lease)
    # rubocop:enable Rails/Delegate

    private

    def validate_settlement!(credit:, debit:, amount:)
      raise ArgumentError, "Amount must be positive" unless amount.positive?
      raise ArgumentError, "Insufficient credit balance" if amount > credit.balance.abs
      raise ArgumentError, "Insufficient debit balance" if amount > debit.balance.abs
    end

    def create_entry(instrument:, amount:, transaction_id:)
      Entry.create!(lease: instrument.lease, instrument: instrument, amount: amount, transaction_id: transaction_id)
    end

    def settle_credit(credit, except: nil)
      lease = credit.lease
      remaining = credit.balance.abs

      unsettled_debits(lease, except: except).each do |debit|
        break if remaining.zero?
        next if debit.balance.abs.zero? # a zero-total finalized invoice has no headroom to settle

        allocation = [remaining, debit.balance.abs].min
        settle(credit: credit, debit: debit, amount: allocation)

        remaining -= allocation
      end
    end

    def settle_debit(debit)
      lease = debit.lease
      remaining = debit.balance.abs

      unsettled_credits(lease).each do |credit|
        break if remaining <= 0
        next if credit.balance.abs.zero? # nothing to draw from a zeroed credit

        allocation = [remaining, credit.balance.abs].min
        settle(credit: credit, debit: debit, amount: allocation)
        remaining -= allocation
      end
    end

    def unsettled_debits(lease, except: nil)
      invoices = lease.invoices.invoice.unsettled.order(:date, :created_at)
      refunds = lease.payments.refund.unsettled.order(:date, :created_at)
      debits = (invoices + refunds).sort_by { |i| [i.date, i.created_at] }
      except ? debits.reject { |debit| debit == except } : debits
    end

    def unsettled_credits(lease)
      payments = lease.payments.payment.unsettled.order(:date, :created_at)
      credit_notes = lease.invoices.credit_note.unsettled.order(:date, :created_at)
      (payments + credit_notes).sort_by { |i| [i.date, i.created_at] }
    end
  end
end
