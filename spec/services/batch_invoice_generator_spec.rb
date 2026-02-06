# frozen_string_literal: true

require "rails_helper"

RSpec.describe BatchInvoiceGenerator do
  describe "#call" do
    subject(:generate_invoices) { described_class.new(date).call }

    let(:date) { Date.current }
    let!(:active_lease) { create(:lease, start_date: date - 1.month, duration_months: 12) }
    let!(:expired_lease) { create(:lease, start_date: date - 2.years, duration_months: 12) }
    let!(:future_lease) { create(:lease, start_date: date + 1.month, duration_months: 12) }

    it "creates invoices for active leases", :aggregate_failures do
      expect { generate_invoices }.to change(Invoice, :count).by(1)
      expect(Invoice.last.lease).to eq(active_lease)
    end

    it "does not create invoices for expired leases" do
      generate_invoices
      expect(Invoice.joins(:line_items).where(lease: expired_lease, line_items: { category: "rent" })).to be_empty
    end

    it "does not create invoices for future leases" do
      generate_invoices
      expect(Invoice.joins(:line_items).where(lease: future_lease, line_items: { category: "rent" })).to be_empty
    end

    context "when rental invoice already exists" do
      before do
        invoice = create(:invoice, lease: active_lease, date: date.beginning_of_month)
        invoice.line_items.create!(name: "Rent", amount: 1000, category: "rent")
      end

      it "does not create a duplicate invoice" do
        expect { generate_invoices }.not_to change(Invoice, :count)
      end
    end

    context "when only security deposit invoice exists" do
      before do
        invoice = create(:invoice, lease: active_lease, date: date.beginning_of_month)
        invoice.line_items.create!(name: "Security Deposit", amount: 2000, category: "security_deposit")
      end

      it "creates a rental invoice" do
        expect { generate_invoices }.to change(Invoice, :count).by(1)
      end
    end
  end
end
