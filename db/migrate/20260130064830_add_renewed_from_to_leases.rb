class AddRenewedFromToLeases < ActiveRecord::Migration[8.1]
  def change
    add_reference :leases, :renewed_from, foreign_key: { to_table: :leases }, null: true
  end
end
