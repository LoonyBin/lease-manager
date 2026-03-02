class CreateUserAssociations < ActiveRecord::Migration[8.1]
  def change
    create_table :user_associations do |t|
      t.references :user, null: false, foreign_key: true
      t.references :associable, polymorphic: true, null: false

      t.timestamps
    end

    add_index :user_associations, %i[user_id associable_type associable_id], unique: true, name: "index_user_associations_uniqueness"
  end
end
