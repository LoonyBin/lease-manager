class CreateInvoices < ActiveRecord::Migration[8.0]
  def change
    create_table :invoices do |t|
      t.references :lease, null: false, foreign_key: true
      t.date :date
      t.integer :status, default: 0
      t.string :number
      t.integer :sequence_number

      t.timestamps
    end
  end
end
