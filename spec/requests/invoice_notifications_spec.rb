# frozen_string_literal: true

require "rails_helper"

RSpec.describe "InvoiceNotifications" do
  before { sign_in_admin }

  let(:lease) { create(:lease) }
  let(:invoice) { create(:invoice, lease: lease, status: :finalized) }
  let(:notification) { create(:invoice_notification, invoice: invoice) }

  describe "GET /invoice_notifications" do
    it "returns http success" do
      notification
      get invoice_notifications_path
      expect(response).to have_http_status(:success)
    end

    it "lists queued reminders" do
      recipient = notification.recipient_email
      get invoice_notifications_path
      expect(response.body).to include(recipient)
    end

    context "when filtering by status" do
      let(:sent_row) do
        create(:invoice_notification, :sent, invoice: invoice, recipient_email: "already.sent@example.com",
                                             occurrence_on: Date.current + 1.day)
      end

      before do
        notification
        sent_row
        get invoice_notifications_path(q: { status_eq: InvoiceNotification.statuses[:pending] })
      end

      it "keeps the matching rows" do
        expect(response.body).to include(notification.recipient_email)
      end

      it "drops the others" do
        expect(response.body).not_to include(sent_row.recipient_email)
      end
    end

    it "serves JSON for API tokens" do
      notification
      get invoice_notifications_path, headers: { "Accept" => "application/json" }
      expect(response).to have_http_status(:success)
    end
  end

  describe "PATCH /invoice_notifications/:id/approve" do
    it "approves the notification and enqueues the send", :aggregate_failures do
      expect { patch approve_invoice_notification_path(notification) }
        .to have_enqueued_job(SendInvoiceNotificationJob).with(notification)
      expect(notification.reload).to be_approved
      expect(response).to redirect_to(invoice_notifications_path)
    end

    it "refuses a notification that is not pending", :aggregate_failures do
      already_sent = create(:invoice_notification, :sent, invoice: invoice)

      expect { patch approve_invoice_notification_path(already_sent) }
        .not_to have_enqueued_job(SendInvoiceNotificationJob)
      expect(already_sent.reload).to be_sent
      expect(flash[:alert]).to eq("That reminder is no longer pending approval.")
    end
  end

  describe "PATCH /invoice_notifications/:id/cancel" do
    it "cancels a pending notification", :aggregate_failures do
      patch cancel_invoice_notification_path(notification)
      expect(notification.reload).to be_cancelled
      expect(response).to redirect_to(invoice_notifications_path)
    end

    it "cancels a failed notification" do
      failed = create(:invoice_notification, :failed, invoice: invoice)
      patch cancel_invoice_notification_path(failed)
      expect(failed.reload).to be_cancelled
    end

    it "refuses an already-sent notification", :aggregate_failures do
      sent = create(:invoice_notification, :sent, invoice: invoice)
      patch cancel_invoice_notification_path(sent)
      expect(sent.reload).to be_sent
      expect(flash[:alert]).to eq("Only pending or failed reminders can be cancelled.")
    end
  end

  describe "PATCH /invoice_notifications/:id/retry" do
    it "returns a failed notification to pending", :aggregate_failures do
      failed = create(:invoice_notification, :failed, invoice: invoice)
      patch retry_invoice_notification_path(failed)
      expect(failed.reload).to be_pending
      expect(failed.last_error).to be_nil
    end

    it "refuses a pending notification" do
      patch retry_invoice_notification_path(notification)
      expect(flash[:alert]).to eq("Only failed reminders can be retried.")
    end
  end

  describe "PATCH /invoice_notifications/approve_all" do
    context "with a mix of pending and already-sent rows" do
      let(:second) { create(:invoice_notification, invoice: invoice, recipient_email: "second@example.com") }
      let(:sent) { create(:invoice_notification, :sent, invoice: invoice, recipient_email: "sent@example.com") }

      before do
        notification
        second
        sent
        patch approve_all_invoice_notifications_path
      end

      it "approves every pending notification", :aggregate_failures do
        expect(notification.reload).to be_approved
        expect(second.reload).to be_approved
      end

      it "leaves an already-sent notification alone" do
        expect(sent.reload).to be_sent
      end
    end

    it "enqueues a send for each" do
      notification
      create(:invoice_notification, invoice: invoice, recipient_email: "second@example.com")

      expect { patch approve_all_invoice_notifications_path }
        .to have_enqueued_job(SendInvoiceNotificationJob).twice
    end

    it "honours the active filter so it never reaches past the visible list", :aggregate_failures do
      other_lease_notification = create(:invoice_notification)
      notification

      patch approve_all_invoice_notifications_path(q: { invoice_lease_id_eq: lease.id })
      expect(notification.reload).to be_approved
      expect(other_lease_notification.reload).to be_pending
    end
  end

  describe "authorization" do
    it "denies the outbox to a non-admin", :aggregate_failures do
      notification
      sign_in_user
      get invoice_notifications_path
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq(I18n.t("authorization.not_authorized"))
    end

    # Approving a send is outward-facing, so it stays admin-only even for the
    # owner of the property the invoice belongs to.
    context "when a non-admin owns the property" do
      let(:owner_user) { create(:user) }

      before do
        notification
        create(:user_association, user: owner_user, associable: lease.property.owner)
        sign_in_as(owner_user)
        patch approve_invoice_notification_path(notification)
      end

      it "does not approve the reminder" do
        expect(notification.reload).to be_pending
      end
    end
  end
end
