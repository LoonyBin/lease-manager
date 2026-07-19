# frozen_string_literal: true

class CreateReminderSteps < ActiveRecord::Migration[8.1]
  def change
    create_table :reminder_steps do |t|
      t.references :lease, null: false, foreign_key: true
      t.integer :position, null: false
      t.integer :offset_days, null: false
      t.integer :repeat_every_days
      t.string :subject, null: false
      t.text :body, null: false
      t.string :to_emails, array: true, default: [], null: false

      t.timestamps
    end

    add_index :reminder_steps, %i[lease_id position]
  end
end
