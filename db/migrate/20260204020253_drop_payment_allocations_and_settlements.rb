class DropPaymentAllocationsAndSettlements < ActiveRecord::Migration[8.1]
  def up
    drop_table :settlements if table_exists?(:settlements)
    drop_table :payment_allocations if table_exists?(:payment_allocations)
  end

  def down
    # Recreate settlements table
    create_table :settlements do |t|
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.references :source, polymorphic: true, null: false
      t.references :target, polymorphic: true, null: false
      t.timestamps
    end

    # Recreate payment_allocations table
    create_table :payment_allocations do |t|
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.references :payment, null: false, foreign_key: true
      t.references :invoice, null: false, foreign_key: true
      t.timestamps
    end
  end
end
