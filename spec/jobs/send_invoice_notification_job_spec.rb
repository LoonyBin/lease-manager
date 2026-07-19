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

    # Otherwise the row sits in the outbox as `approved` forever, looking like
    # a send that is still coming.
    it "cancels an approved notification that is no longer deliverable", :aggregate_failures do
      notification = create(:invoice_notification, :approved, invoice: invoice)
      invoice.update!(status: :paid)

      described_class.new.perform(notification.reload)

      expect(notification.reload).to be_cancelled
      expect(notification.last_error).to eq(I18n.t("invoice_notifications.undeliverable.invoice_settled"))
    end

    it "leaves an already-terminal notification alone" do
      notification = create(:invoice_notification, :cancelled, invoice: invoice)
      expect { described_class.new.perform(notification) }.not_to(change { notification.reload.attributes })
    end

    it "does not send the same notification twice" do
      notification = create(:invoice_notification, :sent, invoice: invoice)
      described_class.new.perform(notification)
      expect(Reminders::Delivery).not_to have_received(:call)
    end
  end
end
