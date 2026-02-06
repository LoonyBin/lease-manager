class AddPartialLeasingToPropertiesAndLeases < ActiveRecord::Migration[8.1]
  def change
    add_column :properties, :capacity, :integer, default: 1, null: false
    add_column :properties, :unit, :string, default: "Unit", null: false
    add_column :leases, :quantity, :integer, default: 1, null: false
  end
end
