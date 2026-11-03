# frozen_string_literal: true

class SendInvoiceNotificationJob < ApplicationJob
  queue_as :default

  discard_on ActiveJob::DeserializationError

  # Re-checks the notification's state at run time: it may have been
  # cancelled, or the invoice settled, between approval and dispatch. An
  # approved row that is no longer deliverable is retired here rather than left
  # approved forever, so the outbox never shows a queued send that will never
  # happen.
  def perform(notification)
    unless notification.deliverable?
      Rails.logger.info("Skipping reminder notification #{notification.id} (status #{notification.status})")
      retire(notification) if notification.approved?
      return
    end

    Reminders::Delivery.call(notification)
  end

  private

  def retire(notification)
    reason = notification.undeliverable_reason
    return if reason.blank?

    notification.cancel_undeliverable!(reason)
  end
end
