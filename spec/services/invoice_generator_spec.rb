# frozen_string_literal: true

require "rails_helper"

RSpec.describe InvoiceGenerator do
  subject(:service) { described_class.new(lease, date) }

  let(:lease) { create(:lease, rent_amount: 1000) }
  let(:date) { Date.new(2025, 2, 1) }

  describe "#call" do
    it "creates an invoice" do
      expect { service.call }.to change(Invoice, :count).by(1)
    end

    it "creates a draft invoice for the correct month" do
      expect(service.call).to have_attributes(persisted?: true, date: date.beginning_of_month,
                                              status: "draft", lease: lease)
    end

    it "creates a rent line item with correct amount" do
      line_item = service.call.line_items.find_by(category: "rent")
      expect(line_item).to have_attributes(present?: true, amount: 1000, name: "Rent for February 2025")
    end

    context "with enhanced rent" do
      let(:lease) do
        create(:lease,
               rent_amount: 1000,
               start_date: Date.new(2024, 1, 1),
               enhancement_period_months: 12,
               enhancement_amount: 10,
               enhancement_type: :percentage)
      end
      let(:date) { Date.new(2025, 1, 1) } # 1 year later, 10% increase

      it "calculates correct enhanced rent" do
        invoice = service.call
        line_item = invoice.line_items.find_by(category: "rent")
        expect(line_item.amount).to eq(1100.0)
      end
    end

    context "when invoice already exists" do
      before { create(:invoice, lease: lease, date: date.beginning_of_month) }

      it "does not create a new invoice" do
        expect { service.call }.not_to change(Invoice, :count)
      end

      it "returns the existing invoice" do
        invoice = service.call
        expect(invoice).to eq(Invoice.find_by(lease: lease, date: date.beginning_of_month))
      end
    end
  end
end
