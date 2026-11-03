# frozen_string_literal: true

class AddArchivedAtToLeases < ActiveRecord::Migration[8.0]
  def change
    add_column :leases, :archived_at, :datetime, null: true, default: nil
    add_index :leases, :archived_at
  end
end
