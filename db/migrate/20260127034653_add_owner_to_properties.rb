class AddOwnerToProperties < ActiveRecord::Migration[8.0]
  class Owner < ActiveRecord::Base; end
  def change
    add_reference :properties, :owner, null: true, foreign_key: true

    reversible do |dir|
      dir.up do
        # Create a default owner if there are properties but no owners
        if Property.exists? && Owner.count == 0
          default_owner = Owner.create!(name: "Default Owner", address: "Please Update Address")
          Property.update_all(owner_id: default_owner.id)
        end

        # Now enforce non-null constraint
        change_column_null :properties, :owner_id, false
      end
    end
  end
end
