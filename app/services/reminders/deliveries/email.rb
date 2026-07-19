# frozen_string_literal: true

module Reminders
  module Deliveries
    # Email delivery: the only channel implemented for v1. Additional
    # channels register in Reminders::Delivery and implement #deliver.
    class Email
      def initialize(notification)
        @notification = notification
      end

      def deliver
        ReminderMailer.reminder(@notification).deliver_now
      end
    end
  end
end
