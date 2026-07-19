# frozen_string_literal: true

require "rails_helper"

RSpec.describe InvoiceNotification do
  subject(:notification) { build(:invoice_notification) }

  describe "associations" do
    it { is_expected.to belong_to(:invoice) }
    it { is_expected.to belong_to(:reminder_step).optional }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:occurrence_on) }
    it { is_expected.to validate_presence_of(:subject) }
    it { is_expected.to validate_presence_of(:body) }

    it "rejects a malformed recipient" do
      expect(build(:invoice_notification, recipient_email: "nope")).not_to be_valid
    end

    it "enforces one row per invoice, step, recipient and occurrence" do
      existing = create(:invoice_notification)
      duplicate = build(:invoice_notification, invoice: existing.invoice, reminder_step: existing.reminder_step,
                                               recipient_email: existing.recipient_email,
                                               occurrence_on: existing.occurrence_on)
      expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "allows the same step and recipient on a later occurrence" do
      existing = create(:invoice_notification)
      duplicate = build(:invoice_notification, invoice: existing.invoice, reminder_step: existing.reminder_step,
                                               recipient_email: existing.recipient_email,
                                               occurrence_on: existing.occurrence_on + 14.days)
      expect(duplicate.save).to be(true)
    end
  end

  describe "#recipient_email=" do
    it "normalises the address" do
      expect(build(:invoice_notification, recipient_email: " Tenant@Example.COM ").recipient_email)
        .to eq("tenant@example.com")
    end
  end

  describe "status predicates" do
    it "allows approving only while pending", :aggregate_failures do
      expect(build(:invoice_notification)).to be_approvable
      expect(build(:invoice_notification, :approved)).not_to be_approvable
      expect(build(:invoice_notification, :sent)).not_to be_approvable
    end

    it "allows cancelling while pending or failed", :aggregate_failures do
      expect(build(:invoice_notification)).to be_cancellable
      expect(build(:invoice_notification, :failed)).to be_cancellable
      expect(build(:invoice_notification, :sent)).not_to be_cancellable
    end

    it "allows retrying only after a failure", :aggregate_failures do
      expect(build(:invoice_notification, :failed)).to be_retryable
      expect(build(:invoice_notification)).not_to be_retryable
    end
  end

  describe "#deliverable?" do
    let(:invoice) { create(:invoice, status: :finalized) }

    it "is true for an approved notification on an unsettled invoice" do
      expect(build(:invoice_notification, :approved, invoice: invoice)).to be_deliverable
    end

    it "is false while still pending" do
      expect(build(:invoice_notification, invoice: invoice)).not_to be_deliverable
    end

    it "is false once the invoice has settled" do
      notification = create(:invoice_notification, :approved, invoice: invoice)
      invoice.update!(status: :paid)
      expect(notification.reload).not_to be_deliverable
    end

    it "is false once the lease has opted out of reminders" do
      notification = create(:invoice_notification, :approved, invoice: invoice)
      invoice.lease.update!(reminders_enabled: false)
      expect(notification.reload).not_to be_deliverable
    end

    it "is false once the lease has been archived" do
      notification = create(:invoice_notification, :approved, invoice: invoice)
      # A lease can only be archived after it is terminated.
      invoice.lease.update!(terminated_on: Date.current, archived_at: Time.current)
      expect(notification.reload).not_to be_deliverable
    end
  end

  describe "#claim_for_delivery!" do
    it "claims an approved row exactly once", :aggregate_failures do
      notification = create(:invoice_notification, :approved)

      expect(notification.claim_for_delivery!).to be(true)
      expect(notification.reload).to be_sending
      # A second worker holding the same stale record finds nothing to claim.
      expect(notification.claim_for_delivery!).to be(false)
    end

    it "refuses to claim a row that is not approved" do
      expect(create(:invoice_notification).claim_for_delivery!).to be(false)
    end
  end

  describe "#mark_sent! / #mark_failed!" do
    it "stamps the send", :aggregate_failures do
      notification = create(:invoice_notification, :approved, last_error: "previous failure")
      notification.mark_sent!
      expect(notification).to be_sent
      expect(notification.sent_at).to be_present
      expect(notification.last_error).to be_nil
    end

    it "records the failure", :aggregate_failures do
      notification = create(:invoice_notification, :approved)
      notification.mark_failed!("boom")
      expect(notification).to be_failed
      expect(notification.last_error).to eq("boom")
    end

    it "truncates a runaway error" do
      notification = create(:invoice_notification, :approved)
      notification.mark_failed!("x" * 5000)
      expect(notification.last_error.length).to eq(described_class::MAX_ERROR_LENGTH)
    end

    # Without this the row stays `sending` forever: the worker has already
    # claimed it, so nothing else will ever pick it up.
    it "still reaches a terminal state when the row cannot be saved", :aggregate_failures do
      notification = create(:invoice_notification, :approved)
      notification.claim_for_delivery!
      allow(notification).to receive(:update!).and_raise(ActiveRecord::RecordInvalid.new(notification))

      notification.mark_failed!("boom")

      expect(notification.reload).to have_attributes(status: "failed", last_error: "boom")
    end
  end

  describe "#undeliverable_reason" do
    let(:invoice) { create(:invoice, status: :finalized) }

    it "is nil while the notification can still go out" do
      expect(create(:invoice_notification, :approved, invoice: invoice).undeliverable_reason).to be_nil
    end

    it "names a settled invoice" do
      notification = create(:invoice_notification, :approved, invoice: invoice)
      invoice.update!(status: :paid)
      expect(notification.reload.undeliverable_reason).to eq(
        I18n.t("invoice_notifications.undeliverable.invoice_settled")
      )
    end

    it "names a lease that stopped reminding" do
      notification = create(:invoice_notification, :approved, invoice: invoice)
      invoice.lease.update!(reminders_enabled: false)
      expect(notification.reload.undeliverable_reason).to eq(
        I18n.t("invoice_notifications.undeliverable.reminders_disabled")
      )
    end
  end

  describe "#cancel_undeliverable!" do
    it "retires the row with its reason", :aggregate_failures do
      notification = create(:invoice_notification, :approved)
      notification.cancel_undeliverable!("nothing left to chase")
      expect(notification).to be_cancelled
      expect(notification.last_error).to eq("nothing left to chase")
    end
  end

  describe "scopes" do
    it "lists pending and approved rows as queued", :aggregate_failures do
      pending_row = create(:invoice_notification)
      approved = create(:invoice_notification, :approved, occurrence_on: Date.current + 1.day)
      sent = create(:invoice_notification, :sent, occurrence_on: Date.current + 2.days)

      expect(described_class.queued).to include(pending_row, approved)
      expect(described_class.queued).not_to include(sent)
    end
  end
end
