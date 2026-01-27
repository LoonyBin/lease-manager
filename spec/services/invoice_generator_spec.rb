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

    context "with tax configured" do
      let(:lease) { create(:lease, rent_amount: 1000, tax_name: "GST", tax_rate: 18) }

      it "creates a tax line item" do
        invoice = service.call
        tax_item = invoice.line_items.find_by(category: "tax")
        expect(tax_item).to have_attributes(present?: true, amount: 180.0, name: "GST (18.0%)")
      end

      it "creates both rent and tax line items" do
        invoice = service.call
        expect(invoice.line_items.count).to eq(2)
      end
    end

    context "with proration (first month mid-start)" do
      let(:lease) { create(:lease, rent_amount: 3100, start_date: Date.new(2025, 1, 16)) }
      let(:date) { Date.new(2025, 1, 1) }

      it "creates a discount line item for unused days" do
        invoice = service.call
        discount_item = invoice.line_items.find_by(category: "discount")
        # 15 unused days (Jan 1-15) at 3100/31 = 100/day = -1500
        expect(discount_item).to have_attributes(present?: true, name: "Pro-rated discount (15 days)")
      end

      it "calculates correct discount amount" do
        invoice = service.call
        discount_item = invoice.line_items.find_by(category: "discount")
        expect(discount_item.amount).to eq(-1500.0)
      end
    end

    context "with proration and tax" do
      let(:lease) do
        create(:lease, rent_amount: 3100, start_date: Date.new(2025, 1, 16), tax_name: "GST", tax_rate: 10)
      end
      let(:date) { Date.new(2025, 1, 1) }

      it "calculates tax on net rent (rent - discount)" do
        invoice = service.call
        tax_item = invoice.line_items.find_by(category: "tax")
        # Net rent = 3100 - 1500 = 1600, tax = 1600 * 10% = 160
        expect(tax_item.amount).to eq(160.0)
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
