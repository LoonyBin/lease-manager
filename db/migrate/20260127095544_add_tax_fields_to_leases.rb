class AddTaxFieldsToLeases < ActiveRecord::Migration[8.0]
  def change
    add_column :leases, :tax_name, :string
    add_column :leases, :tax_rate, :decimal, precision: 5, scale: 2
  end
end
