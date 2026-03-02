# frozen_string_literal: true

class SettlementService
  class << self
    def auto_settle(instrument)
      return unless instrument.balance.abs.positive?

      if instrument.credit?
        settle_credit(instrument)
      else
        settle_debit(instrument)
      end
    end

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def settle(credit:, debit:, amount:)
      raise ArgumentError, "Amount must be positive" unless amount.positive?
      raise ArgumentError, "Insufficient credit balance" if amount > credit.balance.abs
      raise ArgumentError, "Insufficient debit balance" if amount > debit.balance.abs

      transaction_id = SecureRandom.uuid

      ActiveRecord::Base.transaction do
        # Credit entry: positive (uses up credit, moves toward 0)
        Entry.create!(
          lease: credit.lease,
          instrument: credit,
          amount: amount,
          transaction_id: transaction_id
        )

        # Debit entry: negative (pays down debt, moves toward 0)
        Entry.create!(
          lease: debit.lease,
          instrument: debit,
          amount: -amount,
          transaction_id: transaction_id
        )

        credit.recalculate_balance!
        debit.recalculate_balance!
      end

      transaction_id
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    def readjust(lease)
      old_balance = lease.entries.sum(:amount)
      settlement_count = 0
      credit_count = 0

      ActiveRecord::Base.transaction do
        settlement_count = clear_settlements(lease)
        recalculate_balances(lease)
        credit_count = resettle_credits(lease)
      end

      { settlement_count: settlement_count, credit_count: credit_count,
        old_balance: old_balance, new_balance: lease.entries.sum(:amount) }
    end

    private

    def clear_settlements(lease)
      lease.entries.settlements.delete_all
    end

    def recalculate_balances(lease)
      lease.invoices.finalized_or_later.find_each(&:recalculate_balance!)
      lease.payments.confirmed_or_later.find_each(&:recalculate_balance!)
    end

    def resettle_credits(lease)
      credits = chronological_credits(lease)
      credits.each { |credit| auto_settle(credit) }
      credits.size
    end

    def settle_credit(credit)
      lease = credit.lease
      remaining = credit.balance.abs

      unsettled_debits(lease).each do |debit|
        break if remaining.zero?

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

        allocation = [remaining, credit.balance.abs].min
        settle(credit: credit, debit: debit, amount: allocation)
        remaining -= allocation
      end
    end

    def unsettled_debits(lease)
      invoices = lease.invoices.invoice.unsettled.order(:date, :created_at)
      refunds = lease.payments.refund.unsettled.order(:date, :created_at)
      (invoices + refunds).sort_by { |i| [i.date, i.created_at] }
    end

    def unsettled_credits(lease)
      payments = lease.payments.payment.unsettled.order(:date, :created_at)
      credit_notes = lease.invoices.credit_note.unsettled.order(:date, :created_at)
      (payments + credit_notes).sort_by { |i| [i.date, i.created_at] }
    end

    def chronological_credits(lease)
      payments = lease.payments.payment.unsettled.to_a
      credit_notes = lease.invoices.credit_note.unsettled.to_a
      (payments + credit_notes).sort_by { |i| [i.date, i.created_at] }
    end
  end
end
