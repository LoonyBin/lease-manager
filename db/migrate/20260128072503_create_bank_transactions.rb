class CreateBankTransactions < ActiveRecord::Migration[8.1]
  def change
    create_table :bank_transactions do |t|
      t.references :bank_statement, null: false, foreign_key: true
      t.date :date
      t.decimal :amount, precision: 10, scale: 2
      t.string :description
      t.string :reference
      t.references :matched_payment, null: true, foreign_key: { to_table: :payments }
      t.integer :status, default: 0

      t.timestamps
    end
  end
end
