class CreateLineItems < ActiveRecord::Migration[8.0]
  def change
    create_table :line_items do |t|
      t.references :invoice, null: false, foreign_key: true
      t.string :name
      t.decimal :amount, precision: 10, scale: 2
      t.string :category

      t.timestamps
    end
  end
end
