# frozen_string_literal: true

require "rails_helper"

RSpec.describe InvoiceTemplates::Context do
  subject(:variables) { described_class.new(lease, date).variables }

  let(:lease) { create(:lease, start_date: Date.new(2025, 1, 1), duration_months: 12, rent_amount: 1000) }
  let(:date) { Date.new(2025, 3, 15) }

  it "exposes exactly the documented variable names" do
    expect(variables.keys).to match_array(InvoiceTemplates::Context::VARIABLE_NAMES)
  end

  it "normalizes the date to the beginning of the month" do
    expect(variables["invoice_date"]).to eq(Date.new(2025, 3, 1))
  end

  it "exposes the rent with its alias", :aggregate_failures do
    expect(variables["rent"]).to eq(1000)
    expect(variables["r"]).to eq(1000)
  end

  it "exposes month metadata", :aggregate_failures do
    expect(variables["month_name"]).to eq("March")
    expect(variables["year"]).to eq(2025)
    expect(variables["days_in_month"]).to eq(31)
    expect(variables["n"]).to eq(31)
  end

  context "with a fully occupied month" do
    it "sets prorata to 1", :aggregate_failures do
      expect(variables["prorata"]).to eq(1)
      expect(variables["f"]).to eq(1)
      expect(variables["occupied_days"]).to eq(31)
      expect(variables["unused_days"]).to eq(0)
    end
  end

  context "when the lease starts mid-month" do
    let(:lease) { create(:lease, start_date: Date.new(2025, 1, 16), duration_months: 12, rent_amount: 1000) }
    let(:date) { Date.new(2025, 1, 1) }

    it "computes the occupied fraction", :aggregate_failures do
      expect(variables["occupied_days"]).to eq(16)
      expect(variables["unused_days"]).to eq(15)
      expect(variables["prorata"]).to eq(16.to_d / 31)
    end
  end

  context "when the lease terminates mid-month" do
    let(:lease) do
      create(:lease, start_date: Date.new(2025, 1, 1), duration_months: 12,
                     rent_amount: 1000, terminated_on: Date.new(2025, 3, 10))
    end

    it "counts only days up to the termination", :aggregate_failures do
      expect(variables["occupied_days"]).to eq(10)
      expect(variables["unused_days"]).to eq(21)
    end
  end

  context "when the month is entirely outside the lease" do
    let(:date) { Date.new(2026, 6, 1) }

    it "clamps occupied days at zero", :aggregate_failures do
      expect(variables["occupied_days"]).to eq(0)
      expect(variables["prorata"]).to eq(0)
    end
  end

  it "applies rent enhancements at the invoice date" do
    enhanced_date = Date.new(2026, 1, 1) # one 12-month period later, +5%
    expect(described_class.new(lease, enhanced_date).variables["rent"]).to eq(1050)
  end
end
