class CreateBankStatements < ActiveRecord::Migration[8.1]
  def change
    create_table :bank_statements do |t|
      t.string :filename
      t.datetime :uploaded_at
      t.integer :status, default: 0

      t.timestamps
    end
  end
end
