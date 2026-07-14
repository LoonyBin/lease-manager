# frozen_string_literal: true

class CreateInvoiceTemplates < ActiveRecord::Migration[8.1]
  def change
    create_table :invoice_templates do |t|
      t.references :lease, null: false, foreign_key: true
      t.string :name, null: false
      t.interval :payment_due_in, null: false, default: "9 days"
      t.date :starts_on
      t.date :ends_on

      t.timestamps
    end
  end
end
