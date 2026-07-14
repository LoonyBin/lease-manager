# frozen_string_literal: true

require "rails_helper"

RSpec.describe InvoiceTemplates::TextRenderer do
  subject(:renderer) { described_class.new(variables) }

  let(:variables) do
    { "month_name" => "March", "year" => 2025, "unused_days" => 15,
      "rent" => BigDecimal("1102.5"), "invoice_date" => Date.new(2025, 3, 1) }
  end

  describe "#render" do
    it "substitutes placeholders" do
      expect(renderer.render("Rent for {month_name} {year}")).to eq("Rent for March 2025")
    end

    it "substitutes numeric placeholders" do
      expect(renderer.render("Pro-rated discount ({unused_days} days)")).to eq("Pro-rated discount (15 days)")
    end

    it "formats decimal values without trailing zeros" do
      expect(renderer.render("Base rent {rent}")).to eq("Base rent 1102.5")
    end

    it "formats whole decimal values as integers" do
      renderer = described_class.new("rent" => BigDecimal("1000.0"))
      expect(renderer.render("Base rent {rent}")).to eq("Base rent 1000")
    end

    it "formats dates" do
      expect(renderer.render("As of {invoice_date}")).to eq("As of March 1, 2025")
    end

    it "is case-insensitive for placeholder names" do
      expect(renderer.render("Rent for {MONTH_NAME}")).to eq("Rent for March")
    end

    it "leaves unknown placeholders untouched" do
      expect(renderer.render("Fee {unknown}")).to eq("Fee {unknown}")
    end

    it "leaves text without placeholders untouched" do
      expect(renderer.render("Fixed maintenance charge")).to eq("Fixed maintenance charge")
    end
  end

  describe ".unknown_placeholders" do
    it "returns an empty array when all placeholders are known" do
      expect(described_class.unknown_placeholders("Rent for {month_name} {year}")).to be_empty
    end

    it "lists placeholders that are not Context variables" do
      expect(described_class.unknown_placeholders("Fee for {mnth} {year}")).to eq(["mnth"])
    end
  end
end
