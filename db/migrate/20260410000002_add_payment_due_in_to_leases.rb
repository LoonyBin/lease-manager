# frozen_string_literal: true

class AddPaymentDueInToLeases < ActiveRecord::Migration[8.1]
  def change
    add_column :leases, :payment_due_in, :interval, null: false, default: "9 days"
  end
end
