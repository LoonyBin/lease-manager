# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentService do
  let(:lease) { create(:lease) }
  # Create invoices with specific dates to ensure order
  let!(:oldest_invoice) { create(:invoice, lease: lease, date: Time.zone.today - 2.months, status: :finalized) }
  let!(:newer_invoice) { create(:invoice, lease: lease, date: Time.zone.today - 1.month, status: :finalized) }

  # Ensure line items sum to known total
  before do
    oldest_invoice.line_items.destroy_all
    create(:line_item, invoice: oldest_invoice, amount: 100)

    newer_invoice.line_items.destroy_all
    create(:line_item, invoice: newer_invoice, amount: 100)
  end

  describe "#call" do
    context "with full payment for first invoice" do
      let(:payment) { create(:payment, lease: lease, amount: 100) }

      it "allocates to the oldest invoice" do
        described_class.new(payment).call
        expect_allocation(oldest: "paid", newer: "finalized", total: 100)
      end
    end

    context "with partial payment" do
      let(:payment) { create(:payment, lease: lease, amount: 50) }

      it "partially pays the oldest invoice" do
        described_class.new(payment).call

        aggregate_failures do
          expect(oldest_invoice.reload.status).to eq("partially_paid")
          expect(oldest_invoice.paid_amount).to eq(50)
        end
      end
    end

    context "with multiple invoices" do
      let(:payment) { create(:payment, lease: lease, amount: 150) }

      it "pays first fully and second partially" do
        described_class.new(payment).call
        expect_allocation(oldest: "paid", newer: "partially_paid", total: 150, newer_paid: 50)
      end
    end

    context "with excess payment" do
      let(:payment) { create(:payment, lease: lease, amount: 250) }

      it "pays all invoices and leaves excess unallocated" do
        described_class.new(payment).call
        expect_allocation(oldest: "paid", newer: "paid", total: 200)
      end
    end
  end

  describe ".allocate_excess" do
    let(:payment) { create(:payment, lease: lease, amount: 300) } # 100 excess initially (200 allocated to inv1, inv2)
    let!(:new_invoice) { create(:invoice, lease: lease, status: :draft, date: Time.zone.today) }

    before do
      # Allocating 200 to existing 2 invoices
      described_class.new(payment).call
      # New invoice setup
      new_invoice.line_items.destroy_all
      create(:line_item, invoice: new_invoice, amount: 50)
      new_invoice.finalized!
    end

    it "allocates existing excess to the new invoice" do
      described_class.allocate_excess(new_invoice)

      aggregate_failures do
        expect(new_invoice.reload.status).to eq("paid")
        expect(payment.payment_allocations.sum(:amount)).to eq(250) # 200 + 50
      end
    end
  end

  def expect_allocation(oldest:, newer:, total:, newer_paid: nil)
    aggregate_failures do
      expect_invoice_statuses(oldest, newer)
      expect(payment.payment_allocations.sum(:amount)).to eq(total)
      expect(newer_invoice.paid_amount).to eq(newer_paid) if newer_paid
    end
  end

  def expect_invoice_statuses(oldest, newer)
    expect(oldest_invoice.reload.status).to eq(oldest)
    expect(newer_invoice.reload.status).to eq(newer)
  end
end
