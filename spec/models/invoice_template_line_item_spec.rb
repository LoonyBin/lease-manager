# frozen_string_literal: true

require "rails_helper"

RSpec.describe InvoiceTemplateLineItem do
  subject(:line_item) { build(:invoice_template_line_item) }

  describe "associations" do
    it { is_expected.to belong_to(:invoice_template).touch(true) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:amount_expression) }
    it { is_expected.to validate_presence_of(:category) }

    it do
      expect(line_item).to validate_numericality_of(:tax_rate)
        .is_greater_than_or_equal_to(0)
        .is_less_than_or_equal_to(100)
        .allow_nil
    end

    it "accepts expressions over known variables" do
      line_item = build(:invoice_template_line_item, amount_expression: "rent * (prorata - 1)")
      expect(line_item).to be_valid
    end

    it "accepts literal amounts" do
      line_item = build(:invoice_template_line_item, amount_expression: "2500")
      expect(line_item).to be_valid
    end

    it "rejects expressions referencing unknown variables", :aggregate_failures do
      line_item = build(:invoice_template_line_item, amount_expression: "rent + maintenance_fee")
      expect(line_item).not_to be_valid
      expect(line_item.errors[:amount_expression])
        .to include("references unknown variables: maintenance_fee")
    end

    it "rejects malformed expressions", :aggregate_failures do
      line_item = build(:invoice_template_line_item, amount_expression: "rent * (")
      expect(line_item).not_to be_valid
      expect(line_item.errors[:amount_expression]).to include("is not a valid expression")
    end

    it "accepts names with known placeholders" do
      line_item = build(:invoice_template_line_item, name: "Rent for {month_name} {year}")
      expect(line_item).to be_valid
    end

    it "rejects names with unknown placeholders", :aggregate_failures do
      line_item = build(:invoice_template_line_item, name: "Rent for {mnth}")
      expect(line_item).not_to be_valid
      expect(line_item.errors[:name]).to include("references unknown placeholders: mnth")
    end
  end
end
