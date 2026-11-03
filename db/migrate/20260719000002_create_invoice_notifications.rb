# frozen_string_literal: true

class CreateInvoiceNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :invoice_notifications do |t|
      t.references :invoice, null: false, foreign_key: true
      t.references :reminder_step, foreign_key: { on_delete: :nullify }
      t.integer :channel, default: 0, null: false
      t.integer :status, default: 0, null: false
      t.date :occurrence_on, null: false
      t.string :recipient_email, null: false
      t.string :subject, null: false
      t.text :body, null: false
      t.datetime :sent_at
      t.text :last_error

      t.timestamps
    end

    # Idempotency: a step fires at most once per invoice, per recipient, per
    # scheduled occurrence, however often the daily scan re-runs.
    add_index :invoice_notifications,
              %i[invoice_id reminder_step_id recipient_email occurrence_on],
              unique: true,
              name: "index_invoice_notifications_uniqueness"
  end
end
