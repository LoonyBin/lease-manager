class AddPropertyScheduleToLeases < ActiveRecord::Migration[8.1]
  def change
    add_column :leases, :property_schedule, :text
  end
end
