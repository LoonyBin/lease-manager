# frozen_string_literal: true

module Reminders
  # The daily scan: walks unsettled invoices on reminder-enabled leases and
  # materialises a pending InvoiceNotification per step occurrence that has
  # come due, with the message rendered at queue time so what an admin
  # approves is exactly what gets sent.
  #
  # Re-runs are idempotent — the unique index on
  # (invoice, step, recipient, occurrence) turns a repeat into a no-op.
  class BatchScheduler
    def initialize(date = Date.current)
      @date = date
    end

    def call
      scheduled = 0
      due_invoices.find_each do |invoice|
        scheduled += schedule_for(invoice)
      end
      scheduled
    end

    private

    def due_invoices
      Invoice.unsettled
             .where.not(due_date: nil)
             .joins(:lease).merge(Lease.not_archived).merge(Lease.reminding)
             .includes(:line_items, lease: [:reminder_steps, :tenant, { property: :owner }])
    end

    # A step whose message fails to render, or whose row loses a race with a
    # concurrent run, must not abort the whole scan (same posture as
    # BatchInvoiceGenerator).
    def schedule_for(invoice)
      variables = Context.new(invoice, today: @date).variables
      invoice.lease.reminder_steps.sum { |step| schedule_step(invoice, step, variables) }
    rescue StandardError => e
      Rails.logger.error("Skipping reminders for invoice #{invoice.id}: #{e.message}")
      0
    end

    def schedule_step(invoice, step, variables)
      occurrence = step.latest_occurrence_for(invoice.due_date, up_to: @date)
      return 0 if occurrence.nil?

      renderer = InvoiceTemplates::TextRenderer.new(variables)
      attributes = { reminder_step: step, occurrence_on: occurrence, channel: :email,
                     subject: renderer.render(step.subject), body: renderer.render(step.body) }

      step.to_emails.count { |email| create_notification(invoice, attributes.merge(recipient_email: email)) }
    end

    def create_notification(invoice, attributes)
      invoice.invoice_notifications.create!(attributes)
      true
    rescue ActiveRecord::RecordNotUnique
      # Already queued for this occurrence — the idempotency guarantee.
      false
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error(
        "Skipping reminder step #{attributes[:reminder_step]&.id} for invoice #{invoice.id}: #{e.message}"
      )
      false
    end
  end
end
