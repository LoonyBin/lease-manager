# frozen_string_literal: true

module Reminders
  class UnknownChannelError < StandardError; end

  # The seam between a queued notification and however it actually goes out.
  # Channels are keyed by InvoiceNotification#channel, so adding SMS or
  # WhatsApp later is a new enum value plus an entry here.
  module Delivery
    # Class names rather than classes, so the registry survives a development
    # reload without holding on to a stale constant.
    CHANNELS = { "email" => "Reminders::Deliveries::Email" }.freeze

    module_function

    # Dispatches the notification and stamps the outcome on it. Returns true
    # when it went out; a failed send is recorded, not raised, so one bad
    # address does not take a batch approval down with it.
    #
    # The row is claimed (approved → sending) before anything leaves the app,
    # so a duplicate job or a second worker finds nothing to claim rather than
    # sending the tenant the same chaser twice.
    def call(notification)
      unless notification.claim_for_delivery!
        Rails.logger.info("Reminder notification #{notification.id} was not claimable; nothing sent")
        return false
      end

      deliver_claimed(notification)
    end

    def deliver_claimed(notification)
      channel_name = CHANNELS.fetch(notification.channel) do
        raise UnknownChannelError, "no delivery configured for channel #{notification.channel.inspect}"
      end
      channel_name.constantize.new(notification).deliver
      notification.mark_sent!
      true
    rescue StandardError => e
      Rails.logger.error("Reminder delivery failed for notification #{notification.id}: #{e.message}")
      notification.mark_failed!(e.message)
      false
    end
  end
end
