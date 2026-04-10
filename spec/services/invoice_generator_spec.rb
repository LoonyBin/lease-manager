# frozen_string_literal: true

require "rails_helper"

RSpec.describe InvoiceGenerator do
  subject(:service) { described_class.new(Invoice.new(lease: lease, date: date)) }

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

    it "sets due_date based on lease payment_due_in duration" do
      lease.update!(payment_due_in: 9.days)
      invoice = service.call
      expect(invoice.due_date).to eq(date.beginning_of_month + 9.days)
    end

    it "sets due_date equal to invoice date when payment_due_in is 0" do
      lease.update!(payment_due_in: 0.days)
      invoice = service.call
      expect(invoice.due_date).to eq(date.beginning_of_month)
    end

    context "with payment due on the 10th of next month" do
      let(:lease) { create(:lease, rent_amount: 1000, payment_due_in: 1.month + 9.days) }

      it "sets due_date to 10th of the following month" do
        expect(service.call.due_date).to eq(Date.new(2025, 3, 10))
      end
    end

    context "with custom payment_due_in" do
      let(:lease) { create(:lease, rent_amount: 1000, payment_due_in: 14.days) }

      it "sets due_date accordingly" do
        expect(service.call.due_date).to eq(date.beginning_of_month + 14.days)
      end
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

    context "when rental invoice already exists" do
      let!(:existing_invoice) do
        invoice = create(:invoice, lease: lease, date: date.beginning_of_month)
        invoice.line_items.create!(name: "Rent", amount: 1000, category: "rent")
        invoice
      end

      it "does not create a new invoice" do
        expect { service.call }.not_to change(Invoice, :count)
      end

      it "returns the existing invoice" do
        expect(service.call).to eq(existing_invoice)
      end
    end

    context "when invoice is a credit note" do
      subject(:service) { described_class.new(invoice) }

      let(:invoice) { Invoice.new(lease: lease, date: date, document_type: :credit_note) }

      it "returns the original invoice unchanged" do
        expect(service.call).to be(invoice)
      end
    end

    context "when lease is missing" do
      subject(:service) { described_class.new(invoice) }

      let(:invoice) { Invoice.new(date: date) }

      it "returns the original invoice unchanged" do
        expect(service.call).to be(invoice)
      end
    end

    context "when date is missing" do
      subject(:service) { described_class.new(invoice) }

      let(:invoice) { Invoice.new(lease: lease) }

      it "returns the original invoice unchanged" do
        expect(service.call).to be(invoice)
      end
    end

    context "when only security deposit invoice exists" do
      before do
        invoice = create(:invoice, lease: lease, date: date.beginning_of_month)
        invoice.line_items.create!(name: "Security Deposit", amount: 2000, category: "security_deposit")
      end

      it "builds a new rental invoice" do
        expect(service.call).to be_new_record
      end

      it "includes a rent line item" do
        result = service.call
        expect(result.line_items.any? { |li| li.category == "rent" }).to be true
      end
    end
  end
end
