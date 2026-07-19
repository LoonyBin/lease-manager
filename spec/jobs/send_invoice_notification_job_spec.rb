# frozen_string_literal: true

require "rails_helper"

RSpec.describe SendInvoiceNotificationJob do
  describe "#perform" do
    let(:invoice) { create(:invoice, status: :finalized) }

    before { allow(Reminders::Delivery).to receive(:call) }

    it "delivers an approved notification" do
      notification = create(:invoice_notification, :approved, invoice: invoice)
      described_class.new.perform(notification)
      expect(Reminders::Delivery).to have_received(:call).with(notification)
    end

    it "skips a notification that is no longer approved" do
      notification = create(:invoice_notification, :cancelled, invoice: invoice)
      described_class.new.perform(notification)
      expect(Reminders::Delivery).not_to have_received(:call)
    end

    it "skips a notification whose invoice has settled in the meantime" do
      notification = create(:invoice_notification, :approved, invoice: invoice)
      invoice.update!(status: :paid)
      described_class.new.perform(notification.reload)
      expect(Reminders::Delivery).not_to have_received(:call)
    end

    it "does not send the same notification twice" do
      notification = create(:invoice_notification, :sent, invoice: invoice)
      described_class.new.perform(notification)
      expect(Reminders::Delivery).not_to have_received(:call)
    end
  end
end
