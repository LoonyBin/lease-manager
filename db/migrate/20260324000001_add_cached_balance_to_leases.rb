# frozen_string_literal: true

class AddCachedBalanceToLeases < ActiveRecord::Migration[8.1]
  def up
    add_column :leases, :cached_balance, :decimal, precision: 10, scale: 2, null: false, default: 0

    # Backfill from existing unsettled invoice balances (finalized=1, sent=2, partially_paid=5)
    execute <<~SQL
      UPDATE leases
      SET cached_balance = (
        SELECT COALESCE(SUM(invoices.balance), 0)
        FROM invoices
        WHERE invoices.lease_id = leases.id
          AND invoices.status IN (1, 2, 5)
      )
    SQL
  end

  def down
    remove_column :leases, :cached_balance
  end
end
