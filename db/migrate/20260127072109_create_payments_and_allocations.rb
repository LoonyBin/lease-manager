class CreatePaymentsAndAllocations < ActiveRecord::Migration[8.0]
  def change
    create_table :payments do |t|
      t.references :lease, null: false, foreign_key: true
      t.date :date, null: false
      t.decimal :amount, precision: 10, scale: 2, null: false

      t.timestamps
    end

    create_table :payment_allocations do |t|
      t.references :payment, null: false, foreign_key: true
      t.references :invoice, null: false, foreign_key: true
      t.decimal :amount, precision: 10, scale: 2, null: false

      t.timestamps
    end
  end
end
