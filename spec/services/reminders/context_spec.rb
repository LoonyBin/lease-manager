# frozen_string_literal: true

require "rails_helper"

RSpec.describe Reminders::Context do
  subject(:variables) { described_class.new(invoice, today: today).variables }

  let(:today) { Date.new(2026, 3, 20) }
  let(:lease) { create(:lease, start_date: Date.new(2026, 1, 1), duration_months: 12, rent_amount: 1000) }
  let(:invoice) do
    invoice = create(:invoice, lease: lease, date: Date.new(2026, 3, 1), due_date: Date.new(2026, 3, 10),
                               status: :draft)
    create(:line_item, invoice: invoice, amount: 1000, tax_rate: 0)
    invoice.update!(status: :finalized)
    invoice.reload
  end

  it "exposes the invoice's own identity and dates", :aggregate_failures do
    expect(variables["invoice_number"]).to eq(invoice.number)
    expect(variables["invoice_date"]).to eq(Date.new(2026, 3, 1))
    expect(variables["due_date"]).to eq(Date.new(2026, 3, 10))
  end

  it "exposes the amounts", :aggregate_failures do
    expect(variables["total_amount"]).to eq(1000)
    expect(variables["balance_due"]).to eq(1000)
  end

  it "counts days past the due date" do
    expect(variables["days_overdue"]).to eq(10)
  end

  it "reports zero days overdue before the due date" do
    context = described_class.new(invoice, today: Date.new(2026, 3, 1))
    expect(context.variables["days_overdue"]).to eq(0)
  end

  it "exposes the parties", :aggregate_failures do
    expect(variables["tenant_name"]).to eq(lease.tenant.name)
    expect(variables["property_name"]).to eq(lease.property.name)
    expect(variables["owner_name"]).to eq(lease.property.owner.name)
  end

  it "links back to the invoice in the app" do
    expect(variables["invoice_url"]).to eq("http://example.com/invoices/#{invoice.id}")
  end

  it "keeps the invoice-template variables available", :aggregate_failures do
    expect(variables["rent"]).to eq(1000)
    expect(variables["month_name"]).to eq("March")
    expect(variables["year"]).to eq(2026)
  end

  it "labels an unnumbered invoice as a draft" do
    draft = create(:invoice, lease: lease, date: Date.new(2026, 3, 1), status: :draft)
    expect(described_class.new(draft).variables["invoice_number"]).to eq("draft")
  end

  describe "VARIABLE_NAMES" do
    it "covers every key the context produces" do
      expect(variables.keys - described_class::VARIABLE_NAMES).to be_empty
    end

    it "includes the invoice-template variables" do
      expect(described_class::VARIABLE_NAMES).to include(*InvoiceTemplates::Context::VARIABLE_NAMES)
    end
  end

  it "still produces reminder variables when the rent cannot be computed" do
    allow(InvoiceTemplates::Context).to receive(:new).and_raise(TypeError, "nil can't be coerced")
    expect(variables["tenant_name"]).to eq(lease.tenant.name)
  end

  it "lets an unexpected error propagate rather than sending a half-rendered message" do
    allow(InvoiceTemplates::Context).to receive(:new).and_raise(ActiveRecord::ConnectionNotEstablished)
    expect { variables }.to raise_error(ActiveRecord::ConnectionNotEstablished)
  end
end
