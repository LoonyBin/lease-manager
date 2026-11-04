class CreateBankTransactions < ActiveRecord::Migration[8.1]
  # Statuses: 0 unmatched, 1 matched, 2 confirmed, 3 rejected, 4 ambiguous.
  LINKED = "(1, 2)".freeze

  def change
    create_table :bank_transactions do |t|
      t.references :bank_statement, null: false, foreign_key: true
      t.date :date, null: false
      t.text :description
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :reference
      t.references :matched_payment, foreign_key: { to_table: :payments }, index: false
      t.integer :status, default: 0, null: false

      t.timestamps
    end

    add_check_constraint :bank_transactions,
                         "(status IN #{LINKED}) = (matched_payment_id IS NOT NULL)",
                         name: "bank_transactions_link_matches_status"
    add_index :bank_transactions, :matched_payment_id,
              unique: true, where: "status IN #{LINKED}",
              name: "index_bank_transactions_on_active_matched_payment_id"
  end
end
