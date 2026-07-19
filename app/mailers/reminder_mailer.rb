# frozen_string_literal: true

class ReminderMailer < ApplicationMailer
  # Sends the snapshot captured when the notification was queued, so a
  # template edited after approval cannot change what was reviewed.
  def reminder(notification)
    @notification = notification

    mail(to: notification.recipient_email, subject: notification.subject)
  end
end
