# frozen_string_literal: true

class AddRemindersEnabledToLeases < ActiveRecord::Migration[8.1]
  def change
    add_column :leases, :reminders_enabled, :boolean, default: true, null: false
  end
end
