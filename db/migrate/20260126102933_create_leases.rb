class CreateLeases < ActiveRecord::Migration[8.0]
  def change
    create_table :leases do |t|
      t.references :property, null: false, foreign_key: true
      t.references :tenant, null: false, foreign_key: true
      t.date :start_date
      t.integer :duration_months
      t.date :terminated_on
      t.decimal :rent_amount
      t.integer :security_deposit_in_months
      t.integer :enhancement_period_months
      t.decimal :enhancement_percentage
      t.decimal :enhancement_fixed_amount

      t.timestamps
    end
  end
end
