# frozen_string_literal: true

require "rails_helper"

RSpec.describe TemplateInvoiceGenerator do
  subject(:service) { described_class.new(template, date) }

  let!(:lease) { create(:lease, rent_amount: 1000, start_date: Date.new(2025, 1, 1), duration_months: 12) }
  let(:template) { lease.invoice_templates.first }
  let(:date) { Date.new(2025, 2, 14) }

  describe "#call" do
    it "does not persist anything" do
      expect { service.call }.not_to change(Invoice, :count)
    end

    it "builds a draft invoice for the month, linked to the template" do
      expect(service.call).to have_attributes(persisted?: false, date: Date.new(2025, 2, 1),
                                              status: "draft", lease: lease, invoice_template: template)
    end

    it "sets due_date from the template payment_due_in" do
      template.update!(payment_due_in: 1.month + 9.days)
      expect(service.call.due_date).to eq(Date.new(2025, 3, 10))
    end

    it "renders placeholders in line item names" do
      rent_line = service.call.line_items.detect { |line| line.category == "rent" }
      expect(rent_line.name).to eq("Rent for February 2025")
    end

    it "copies the template tax rate onto line items" do
      rent_line = service.call.line_items.detect { |line| line.category == "rent" }
      expect(rent_line.tax_rate).to eq(18.0)
    end

    it "drops line items that evaluate to zero" do
      expect(service.call.line_items.map(&:category)).not_to include("discount")
    end

    context "with a partial first month" do
      let(:lease) { create(:lease, rent_amount: 3100, start_date: Date.new(2025, 1, 16), duration_months: 12) }
      let(:date) { Date.new(2025, 1, 1) }
      let(:discount_line) { service.call.line_items.detect { |line| line.category == "discount" } }

      it "keeps the discount line with the evaluated amount", :aggregate_failures do
        expect(discount_line.name).to eq("Pro-rated discount (15 days)")
        expect(discount_line.amount).to eq(-1500.0)
      end
    end

    context "when the month is before the window" do
      let(:date) { Date.new(2024, 12, 1) }

      it "returns nil" do
        expect(service.call).to be_nil
      end
    end

    context "when the month is after the window" do
      let(:date) { Date.new(2026, 1, 1) }

      it "returns nil" do
        expect(service.call).to be_nil
      end
    end

    context "when the lease was terminated before the month" do
      before { lease.update!(terminated_on: Date.new(2025, 1, 20)) }

      it "returns nil for months after termination" do
        expect(service.call).to be_nil
      end
    end

    context "when an invoice from this template already exists for the month" do
      let!(:existing) do
        described_class.new(template, date).call.tap(&:save!)
      end

      it "returns the existing invoice without building a new one" do
        expect(service.call).to eq(existing)
      end

      it "returns the existing invoice even when its date was edited within the month" do
        existing.update!(date: Date.new(2025, 2, 20))
        expect(service.call).to eq(existing)
      end

      it "builds a fresh invoice when find_existing is disabled" do
        expect(described_class.new(template, date, find_existing: false).call).to be_new_record
      end
    end

    context "when a manual invoice without a template link bills rent for the month" do
      let!(:manual_invoice) do
        create(:invoice, lease: lease, date: Date.new(2025, 2, 20)).tap do |invoice|
          invoice.line_items.create!(name: "Rent (manual)", amount: 1000, category: "rent")
        end
      end

      it "returns nil so the batch cannot double-bill rent" do
        expect(service.call).to be_nil
      end

      it "generates again once the manual invoice is cancelled" do
        manual_invoice.update!(status: :cancelled)
        expect(service.call).to be_new_record
      end

      it "still generates for templates that do not bill rent" do
        maintenance = create(:invoice_template, lease: lease, name: "Maintenance").tap do |t|
          t.line_items.first.update!(name: "Maintenance charge", amount_expression: "2500", category: "maintenance")
        end
        expect(described_class.new(maintenance, date).call).to be_new_record
      end

      it "still builds a preview when find_existing is disabled" do
        expect(described_class.new(template, date, find_existing: false).call).to be_new_record
      end
    end

    context "when a manual credit note has a rent line for the month" do
      before do
        credit_note = create(:invoice, :credit_note, lease: lease, date: Date.new(2025, 2, 1))
        credit_note.line_items.create!(name: "Rent adjustment", amount: 500, category: "rent")
      end

      it "still builds a new invoice" do
        expect(service.call).to be_new_record
      end
    end

    context "when a manual invoice has only non-rent lines for the month" do
      before do
        invoice = create(:invoice, lease: lease, date: Date.new(2025, 2, 1))
        invoice.line_items.create!(name: "Security Deposit", amount: 2000, category: "security_deposit")
      end

      it "still builds a new invoice" do
        expect(service.call).to be_new_record
      end
    end

    context "when another template generated an invoice for the month" do
      before do
        other = create(:invoice_template, lease: lease, name: "Maintenance")
        described_class.new(other, date).call.tap(&:save!)
      end

      it "still builds a new invoice for this template" do
        expect(service.call).to be_new_record
      end
    end

    context "when all line items evaluate to zero" do
      let(:template) do
        create(:invoice_template, lease: lease).tap do |t|
          t.line_items.first.update!(amount_expression: "rent * 0", name: "Nothing")
        end
      end

      it "returns nil" do
        expect(service.call).to be_nil
      end
    end

    context "with a fractional total" do
      let(:template) do
        create(:invoice_template, lease: lease).tap do |t|
          t.line_items.first.update!(amount_expression: "1000.51", tax_rate: 0)
        end
      end

      it "appends a rounding line so the total is a whole number", :aggregate_failures do
        invoice = service.call
        round_off = invoice.line_items.detect { |line| line.category == "rounding" }
        expect(round_off).to have_attributes(name: "Round Off", amount: BigDecimal("0.49"), tax_rate: 0)
        expect(invoice.total_amount).to eq(1001)
      end
    end

    context "with a fractional tax-inclusive total" do
      let(:template) do
        create(:invoice_template, lease: lease).tap do |t|
          t.line_items.first.update!(amount_expression: "999", tax_rate: 17.5)
        end
      end

      it "rounds the tax-inclusive total to a whole number", :aggregate_failures do
        invoice = service.call
        # 999 * 1.175 = 1173.83 (rounded), so the rounding line adds 0.17
        round_off = invoice.line_items.detect { |line| line.category == "rounding" }
        expect(round_off.amount).to eq(BigDecimal("0.17"))
        expect(invoice.total_amount).to eq(1174)
      end
    end

    context "with a whole total" do
      it "does not append a rounding line" do
        expect(service.call.line_items.map(&:category)).not_to include("rounding")
      end
    end
  end
end
