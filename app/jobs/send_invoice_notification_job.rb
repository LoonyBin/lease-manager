# frozen_string_literal: true

class SendInvoiceNotificationJob < ApplicationJob
  queue_as :default

  discard_on ActiveJob::DeserializationError

  # Re-checks the notification's state at run time: it may have been
  # cancelled, or the invoice settled, between approval and dispatch.
  def perform(notification)
    unless notification.deliverable?
      Rails.logger.info("Skipping reminder notification #{notification.id} (status #{notification.status})")
      return
    end

    Reminders::Delivery.call(notification)
  end
end
