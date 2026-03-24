# frozen_string_literal: true

require "rails_helper"

RSpec.describe "leases/show" do
  subject { rendered }

  before do
    @lease = assign(:lease, create(:lease))
    @statement_entries = assign(:statement_entries, [])
    render
  end

  it { is_expected.to match(/#{@lease.property.name}/) }
  it { is_expected.to match(/#{@lease.tenant.name}/) }
  it { is_expected.to match(/12 months/) }
  it { is_expected.to match(/₹1,000/) }
  it { is_expected.to have_text("#{@lease.quantity} #{@lease.property.unit}") }
  it { is_expected.to have_text(@lease.property_schedule) }

  it "renders the Statement heading" do
    expect(rendered).to have_css("h3", text: "Statement")
  end

  it "shows empty state when no entries" do
    expect(rendered).to have_text("No finalized transactions yet.")
  end

  context "with finalized invoices and payments" do
    let(:lease) { create(:lease) }

    before do
      inv = create(:invoice, lease: lease, date: Date.new(2025, 1, 15), status: :draft)
      create(:line_item, invoice: inv, amount: 1000, tax_rate: 0)
      inv.update!(status: :finalized)
      create(:payment, lease: lease, date: Date.new(2025, 1, 20), amount: 1000)
      @lease = assign(:lease, lease)
      entries = lease.entries.initial.preload(:instrument)
      @statement_entries = assign(:statement_entries, view.statement_entries(entries))
      render
    end

    it "renders the statement table with column headers", :aggregate_failures do
      expect(rendered).to have_text("Description")
      expect(rendered).to have_text("Debit")
      expect(rendered).to have_text("Credit")
      expect(rendered).to have_text("Balance")
    end

    it "shows invoice and payment rows", :aggregate_failures do
      expect(rendered).to have_text(/Invoice #\d+/)
      expect(rendered).to have_text("Payment")
    end

    it "renders statement rows instead of empty state" do
      expect(rendered).to have_css(".lease-statement-list .resource-item", minimum: 2)
    end
  end
end
