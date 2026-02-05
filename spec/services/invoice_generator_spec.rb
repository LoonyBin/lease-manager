# frozen_string_literal: true

require "rails_helper"

RSpec.describe InvoiceGenerator do
  subject(:service) { described_class.new(lease, date) }

  let!(:lease) { create(:lease, rent_amount: 1000) }
  let(:date) { Date.new(2025, 2, 1) }

  describe "#call" do
    it "does not create an invoice" do
      expect { service.call }.not_to change(Invoice, :count)
    end

    it "builds a draft invoice for the correct month" do
      expect(service.call).to have_attributes(persisted?: false, date: date.beginning_of_month,
                                              status: "draft", lease: lease)
    end

    describe "rent line item" do
      let(:line_item) { service.call.line_items.find { |i| i.category == "rent" } }

      it "is present" do
        expect(line_item).to be_present
      end

      it "has correct attributes" do
        expect(line_item).to have_attributes(amount: 1000, name: "Rent for February 2025")
      end
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
        line_item = invoice.line_items.find { |i| i.category == "rent" }
        expect(line_item.amount).to eq(1100.0)
      end
    end

    context "with tax configured" do
      let(:lease) { create(:lease, rent_amount: 1000, tax_name: "GST", tax_rate: 18) }
      let(:rent_item) { service.call.line_items.find { |i| i.category == "rent" } }

      it "sets tax_rate on the rent line item" do
        expect(rent_item.tax_rate).to eq(18.0)
      end

      it "calculates tax_amount dynamically" do
        expect(rent_item.tax_amount).to eq(180.0)
      end

      it "does not create a separate tax line item" do
        invoice = service.call
        expect(invoice.line_items.find { |i| i.category == "tax" }).to be_nil
      end

      it "calculates correct total for the line item" do
        expect(rent_item.total).to eq(1180.0)
      end
    end

    context "with proration (first month mid-start)" do
      let(:lease) { create(:lease, rent_amount: 3100, start_date: Date.new(2025, 1, 16)) }
      let(:date) { Date.new(2025, 1, 1) }
      let(:discount_item) { service.call.line_items.find { |i| i.category == "discount" } }

      it "creates a discount line item" do
        expect(discount_item).to be_present
      end

      it "has correct name" do
        expect(discount_item.name).to eq("Pro-rated discount (15 days)")
      end

      it "calculates correct discount amount" do
        expect(discount_item.amount).to eq(-1500.0)
      end
    end

    context "with proration and tax" do
      let(:lease) do
        create(:lease, rent_amount: 3100, start_date: Date.new(2025, 1, 16), tax_name: "GST", tax_rate: 10)
      end
      let(:date) { Date.new(2025, 1, 1) }
      let(:invoice) { service.call }
      let(:rent_item) { invoice.line_items.find { |i| i.category == "rent" } }
      let(:discount_item) { invoice.line_items.find { |i| i.category == "discount" } }

      it "sets tax_rate on the rent line item" do
        expect(rent_item.tax_rate).to eq(10.0)
      end

      it "sets tax_rate on the discount line item" do
        expect(discount_item.tax_rate).to eq(10.0)
      end

      it "calculates correct tax amount on the rent line item" do
        expect(rent_item.tax_amount).to eq(310.0)
      end

      it "calculates correct tax amount on the discount line item" do
        expect(discount_item.tax_amount).to eq(-150.0)
      end
    end

    context "when invoice already exists" do
      before { create(:invoice, lease: lease, date: date.beginning_of_month) }

      it "does not create a new invoice" do
        expect { service.call }.not_to change(Invoice, :count)
      end

      it "returns the existing invoice" do
        existing_invoice = Invoice.find_by(lease: lease, date: date.beginning_of_month)
        expect(service.call).to eq(existing_invoice)
      end
    end
  end
end
