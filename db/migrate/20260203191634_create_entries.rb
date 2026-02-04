class CreateEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :entries do |t|
      t.references :lease, null: false, foreign_key: true
      t.references :instrument, polymorphic: true, null: false
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.uuid :transaction_id
      t.timestamps
    end

    add_index :entries, :transaction_id
  end
end
