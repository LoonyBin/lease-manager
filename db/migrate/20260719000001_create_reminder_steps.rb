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

    # Backstop for the model's numericality validation: a zero or negative
    # repeat never advances ReminderStep#occurrences_for, so keep the value
    # unrepresentable even via update_column or raw SQL. NULL still means
    # "fire once".
    add_check_constraint :reminder_steps, "repeat_every_days > 0", name: "reminder_steps_repeat_every_days_positive"
  end
end
