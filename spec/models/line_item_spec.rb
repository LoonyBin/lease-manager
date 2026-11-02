# frozen_string_literal: true

require "rails_helper"

RSpec.describe LineItem do
  describe "associations" do
    it { is_expected.to belong_to(:invoice) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:category) }
    it { is_expected.to validate_presence_of(:amount) }
    it { is_expected.to validate_numericality_of(:amount) }
  end

  describe "#tax_amount" do
    it "is a decimal zero, not an Integer, when there is no tax rate" do
      expect(described_class.new(amount: 100, tax_rate: nil).tax_amount).to be_a(BigDecimal).and eq(0)
    end

    it "serializes a missing tax rate as a decimal string" do
      expect(described_class.new(amount: 100, tax_rate: nil).as_json["tax_amount"]).to eq("0.0")
    end
  end
end
