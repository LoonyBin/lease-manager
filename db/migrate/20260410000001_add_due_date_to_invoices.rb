# frozen_string_literal: true

class AddDueDateToInvoices < ActiveRecord::Migration[8.1]
  def up
    add_column :invoices, :due_date, :date, null: true

    # Backfill: set due_date = date for all existing invoices
    execute <<~SQL
      UPDATE invoices SET due_date = date
    SQL
  end

  def down
    remove_column :invoices, :due_date
  end
end
