class ChangeSecurityDepositInMonthsToDecimal < ActiveRecord::Migration[8.1]
  def change
    change_column :leases, :security_deposit_in_months, :decimal, precision: 5, scale: 2
  end
end
