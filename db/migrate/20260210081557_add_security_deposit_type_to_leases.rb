class AddSecurityDepositTypeToLeases < ActiveRecord::Migration[8.1]
  def change
    rename_column :leases, :security_deposit_in_months, :security_deposit_value
    reversible do |dir|
      dir.up { change_column :leases, :security_deposit_value, :decimal, precision: 12, scale: 2 }
      dir.down { change_column :leases, :security_deposit_value, :decimal, precision: 5, scale: 2 }
    end
    add_column :leases, :security_deposit_type, :integer, default: 0, null: false
  end
end
