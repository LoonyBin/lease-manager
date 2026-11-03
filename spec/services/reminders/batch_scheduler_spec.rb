# frozen_string_literal: true

require "rails_helper"

RSpec.describe Reminders::BatchScheduler do
  subject(:scheduler) { described_class.new(today) }

  let(:today) { Date.new(2026, 3, 20) }
  let(:lease) { create(:lease, start_date: Date.new(2026, 1, 1), duration_months: 12) }

  # Leases seed a default policy on create; specs drive their own steps.
  before { lease.reminder_steps.destroy_all }

  def finalized_invoice(on_lease: lease, due_date: Date.new(2026, 3, 10), amount: 1000)
    invoice = create(:invoice, lease: on_lease, date: due_date.beginning_of_month, due_date: due_date, status: :draft)
    create(:line_item, invoice: invoice, amount: amount, tax_rate: 0)
    invoice.update!(status: :finalized)
    invoice.reload
  end

  describe "#call" do
    context "when a step has come round" do
      let!(:invoice) { finalized_invoice }
      let(:notification) { InvoiceNotification.last }

      before do
        create(:reminder_step, lease: lease, offset_days: -7)
        scheduler.call
      end

      it "queues exactly one notification" do
        expect(InvoiceNotification.count).to eq(1)
      end

      it "queues it against the invoice, pending approval", :aggregate_failures do
        expect(notification.invoice).to eq(invoice)
        expect(notification).to be_pending
      end

      it "stamps the occurrence and recipient", :aggregate_failures do
        expect(notification.occurrence_on).to eq(Date.new(2026, 3, 3))
        expect(notification.recipient_email).to eq("tenant@example.com")
      end
    end

    it "does not queue a step that has not come round yet" do
      finalized_invoice(due_date: Date.new(2026, 4, 10))
      create(:reminder_step, lease: lease, offset_days: 0)

      expect { scheduler.call }.not_to change(InvoiceNotification, :count)
    end

    it "queues a step landing exactly on today" do
      finalized_invoice(due_date: today)
      create(:reminder_step, lease: lease, offset_days: 0)

      expect { scheduler.call }.to change(InvoiceNotification, :count).by(1)
    end

    it "queues one notification per recipient address" do
      finalized_invoice
      create(:reminder_step, :escalated, lease: lease, offset_days: 0)
      scheduler.call

      expect(InvoiceNotification.pluck(:recipient_email))
        .to contain_exactly("collections@example.com", "legal@example.com")
    end

    it "is idempotent across re-runs" do
      finalized_invoice
      create(:reminder_step, lease: lease, offset_days: -7)
      scheduler.call

      expect { scheduler.call }.not_to change(InvoiceNotification, :count)
    end

    it "returns the number of notifications it queued" do
      finalized_invoice
      create(:reminder_step, :escalated, lease: lease, offset_days: 0)

      expect(scheduler.call).to eq(2)
    end

    it "queues only the latest occurrence of a repeating step, not the backlog", :aggregate_failures do
      finalized_invoice(due_date: Date.new(2026, 1, 10))
      create(:reminder_step, lease: lease, offset_days: 7, repeat_every_days: 14)

      # Occurrences run Jan 17, Jan 31, Feb 14, Feb 28, Mar 14 — only the last is queued.
      expect { scheduler.call }.to change(InvoiceNotification, :count).by(1)
      expect(InvoiceNotification.last.occurrence_on).to eq(Date.new(2026, 3, 14))
    end

    it "queues the next occurrence when the scan runs again later" do
      finalized_invoice(due_date: Date.new(2026, 3, 10))
      create(:reminder_step, lease: lease, offset_days: 7, repeat_every_days: 14)
      [scheduler, described_class.new(Date.new(2026, 4, 5))].each(&:call)

      expect(InvoiceNotification.order(:occurrence_on).pluck(:occurrence_on))
        .to eq([Date.new(2026, 3, 17), Date.new(2026, 3, 31)])
    end

    context "when the message has placeholders" do
      let!(:invoice) { finalized_invoice }
      let(:notification) { InvoiceNotification.last }

      before do
        create(:reminder_step, lease: lease, offset_days: 0,
                               subject: "Invoice {invoice_number} for {property_name}",
                               body: "{tenant_name} owes {balance_due}, {days_overdue} days overdue. {invoice_url}")
        scheduler.call
      end

      it "renders the subject into the snapshot" do
        expect(notification.subject).to eq("Invoice #{invoice.number} for #{lease.property.name}")
      end

      it "renders the body into the snapshot" do
        expect(notification.body).to include(lease.tenant.name, "1000", "10 days overdue")
      end

      it "links back to the invoice rather than attaching it" do
        expect(notification.body).to include("http://example.com/invoices/#{invoice.id}")
      end
    end

    it "skips settled invoices" do
      invoice = finalized_invoice
      create(:reminder_step, lease: lease, offset_days: -7)
      invoice.update!(status: :paid)

      expect { scheduler.call }.not_to change(InvoiceNotification, :count)
    end

    it "skips draft invoices" do
      create(:invoice, lease: lease, date: Date.new(2026, 3, 1), due_date: Date.new(2026, 3, 10), status: :draft)
      create(:reminder_step, lease: lease, offset_days: -7)

      expect { scheduler.call }.not_to change(InvoiceNotification, :count)
    end

    it "skips invoices without a due date" do
      invoice = finalized_invoice
      invoice.update_column(:due_date, nil) # rubocop:disable Rails/SkipsModelValidations -- due_date is auto-filled
      create(:reminder_step, lease: lease, offset_days: -7)

      expect { scheduler.call }.not_to change(InvoiceNotification, :count)
    end

    it "skips leases that have opted out" do
      finalized_invoice
      create(:reminder_step, lease: lease, offset_days: -7)
      lease.update!(reminders_enabled: false)

      expect { scheduler.call }.not_to change(InvoiceNotification, :count)
    end

    it "skips archived leases" do
      finalized_invoice
      create(:reminder_step, lease: lease, offset_days: -7)
      lease.update!(terminated_on: Date.new(2026, 6, 30), archived_at: Time.current)

      expect { scheduler.call }.not_to change(InvoiceNotification, :count)
    end

    it "skips leases with no steps at all" do
      finalized_invoice

      expect { scheduler.call }.not_to change(InvoiceNotification, :count)
    end

    it "fires every step whose occurrence has passed, and only those" do
      finalized_invoice
      [-7, 0, 30].each_with_index { |days, i| create(:reminder_step, lease: lease, position: i + 1, offset_days: days) }
      scheduler.call

      expect(InvoiceNotification.pluck(:occurrence_on))
        .to contain_exactly(Date.new(2026, 3, 3), Date.new(2026, 3, 10))
    end

    context "when one invoice's reminders blow up" do
      let!(:broken) { finalized_invoice(due_date: Date.new(2026, 3, 10)) }
      let(:other_lease) do
        create(:lease, start_date: Date.new(2026, 1, 1), duration_months: 12).tap do |l|
          l.reminder_steps.destroy_all
        end
      end
      let!(:healthy) { finalized_invoice(on_lease: other_lease) }

      before do
        create(:reminder_step, lease: lease, offset_days: 0)
        create(:reminder_step, lease: other_lease, offset_days: 0)
        allow(Reminders::Context).to receive(:new).and_wrap_original do |original, invoice, **kwargs|
          raise StandardError, "boom" if invoice.id == broken.id

          original.call(invoice, **kwargs)
        end
        scheduler.call
      end

      it "still queues the healthy invoice's reminder", :aggregate_failures do
        expect(InvoiceNotification.count).to eq(1)
        expect(InvoiceNotification.last.invoice).to eq(healthy)
      end
    end
  end
end
