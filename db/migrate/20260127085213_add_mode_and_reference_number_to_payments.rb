class AddModeAndReferenceNumberToPayments < ActiveRecord::Migration[8.0]
  def change
    add_column :payments, :mode, :integer
    add_column :payments, :reference_number, :string
  end
end
