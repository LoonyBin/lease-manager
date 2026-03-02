class AddDocumentTypeAndBalanceToInvoices < ActiveRecord::Migration[8.1]
  def change
    add_column :invoices, :document_type, :integer, default: 0, null: false
    add_column :invoices, :balance, :decimal, precision: 10, scale: 2, default: 0
  end
end
