class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :uid, null: false
      t.string :provider, null: false
      t.string :email
      t.string :name
      t.integer :role, default: 1, null: false

      t.timestamps
    end

    add_index :users, [:provider, :uid], unique: true
    add_index :users, :email
  end
end
