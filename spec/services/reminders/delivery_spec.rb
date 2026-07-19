# frozen_string_literal: true

require "rails_helper"

RSpec.describe Reminders::Delivery do
  let(:notification) { create(:invoice_notification, :approved, recipient_email: "chaser@example.com") }

  describe ".call" do
    it "marks the notification sent", :aggregate_failures do
      described_class.call(notification)
      expect(notification.reload).to be_sent
      expect(notification.sent_at).to be_present
    end

    it "sends the message to the recipient", :aggregate_failures do
      expect { described_class.call(notification) }.to change(ActionMailer::Base.deliveries, :count).by(1)
      expect(ActionMailer::Base.deliveries.last.to).to eq(["chaser@example.com"])
    end

    it "returns true on success" do
      expect(described_class.call(notification)).to be(true)
    end

    it "records a delivery failure instead of raising", :aggregate_failures do
      allow(ReminderMailer).to receive(:reminder).and_raise(Net::SMTPFatalError, "550 mailbox unavailable")

      expect(described_class.call(notification)).to be(false)
      expect(notification.reload).to be_failed
      expect(notification.last_error).to include("550 mailbox unavailable")
    end

    it "records an unknown channel as a failure", :aggregate_failures do
      stub_const("#{described_class}::CHANNELS", {})

      expect(described_class.call(notification)).to be(false)
      expect(notification.reload.last_error).to include("no delivery configured")
    end

    it "sends nothing when the row is no longer approved" do
      notification.update!(status: :cancelled)

      expect { described_class.call(notification) }.not_to change(ActionMailer::Base.deliveries, :count)
    end

    # A duplicate job (or a second worker) must not chase the tenant twice.
    it "delivers only once when called twice for the same notification", :aggregate_failures do
      expect { described_class.call(notification) }.to change(ActionMailer::Base.deliveries, :count).by(1)
      expect { described_class.call(notification) }.not_to change(ActionMailer::Base.deliveries, :count)
    end
  end
end
