class BackfillLedgerEntries < ActiveRecord::Migration[8.1]
  def up
    # Backfill document_type based on line_items sum (negative total = credit_note)
    execute <<-SQL
      UPDATE invoices
      SET document_type = 1
      WHERE id IN (
        SELECT invoice_id
        FROM line_items
        GROUP BY invoice_id
        HAVING SUM(amount) < 0
      )
    SQL

    # Create initial entries for finalized invoices
    Invoice.where(status: %i[finalized sent paid partially_paid]).find_each do |inv|
      signed_amount = inv.invoice? ? inv.total_amount : -inv.total_amount
      next if signed_amount.zero?

      Entry.create!(
        lease_id: inv.lease_id,
        instrument: inv,
        amount: signed_amount,
        transaction_id: nil
      )
    end

    # Create initial entries for existing payments
    Payment.find_each do |pmt|
      signed_amount = pmt.payment? ? -pmt.amount : pmt.amount
      Entry.create!(
        lease_id: pmt.lease_id,
        instrument: pmt,
        amount: signed_amount,
        transaction_id: nil
      )
    end

    # Convert existing payment_allocations to settlement entry pairs (if table exists)
    if table_exists?(:payment_allocations)
      PaymentAllocation.find_each do |allocation|
        transaction_id = SecureRandom.uuid
        payment = allocation.payment
        invoice = allocation.invoice

        # Payment (credit) entry: positive (uses up credit)
        Entry.create!(
          lease_id: payment.lease_id,
          instrument: payment,
          amount: allocation.amount,
          transaction_id: transaction_id
        )

        # Invoice (debit) entry: negative (reduces debt)
        Entry.create!(
          lease_id: invoice.lease_id,
          instrument: invoice,
          amount: -allocation.amount,
          transaction_id: transaction_id
        )
      end
    end

    # Recalculate all balances
    Invoice.find_each do |inv|
      inv.update_column(:balance, inv.entries.sum(:amount))
    end

    Payment.find_each do |pmt|
      pmt.update_column(:balance, pmt.entries.sum(:amount))
    end
  end

  def down
    Entry.delete_all
    Invoice.update_all(document_type: 0, balance: 0)
    Payment.update_all(balance: 0)
  end
end
