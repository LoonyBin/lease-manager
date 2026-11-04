class CreateBankStatements < ActiveRecord::Migration[8.1]
  def change
    create_table :bank_statements do |t|
      t.string :filename, null: false
      t.datetime :uploaded_at, null: false
      t.integer :status, default: 0, null: false

      t.timestamps
    end
  end
end
