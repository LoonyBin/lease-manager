class AddPaymentTypeAndBalanceToPayments < ActiveRecord::Migration[8.1]
  def change
    add_column :payments, :payment_type, :integer, default: 0, null: false
    add_column :payments, :balance, :decimal, precision: 10, scale: 2, default: 0
  end
end
