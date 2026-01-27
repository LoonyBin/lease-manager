class AddInvoiceSequenceToOwners < ActiveRecord::Migration[8.0]
  def change
    add_column :owners, :invoice_sequence, :integer, default: 0
  end
end
