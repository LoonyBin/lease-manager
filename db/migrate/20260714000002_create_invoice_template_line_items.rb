# frozen_string_literal: true

class CreateInvoiceTemplateLineItems < ActiveRecord::Migration[8.1]
  def change
    create_table :invoice_template_line_items do |t|
      t.references :invoice_template, null: false, foreign_key: true
      t.string :name, null: false
      t.string :amount_expression, null: false
      t.decimal :tax_rate, precision: 5, scale: 3, default: "0.0"
      t.string :category, null: false
      t.integer :position

      t.timestamps
    end
  end
end
