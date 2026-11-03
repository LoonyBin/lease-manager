# frozen_string_literal: true

require "rails_helper"

RSpec.describe InvoiceTemplates::DefaultBuilder do
  subject(:template) { described_class.new(lease).call }

  let(:lease) { create(:lease, tax_rate: 18, payment_due_in: 14.days) }

  it "builds a valid, unsaved template", :aggregate_failures do
    expect(template).to be_new_record
    expect(template).to be_valid
  end

  it "copies the lease payment terms", :aggregate_failures do
    expect(template.name).to eq("Rent")
    expect(template.payment_due_in).to eq(14.days)
  end

  it "leaves the generation window on the lease dates", :aggregate_failures do
    expect(template.starts_on).to be_nil
    expect(template.ends_on).to be_nil
  end

  it "builds a rent line seeded with the lease tax rate" do
    rent_line = template.line_items.detect { |line| line.category == "rent" }
    expect(rent_line).to have_attributes(name: "Rent for {month_name} {year}",
                                         amount_expression: "rent", tax_rate: 18)
  end

  it "builds a pro-rated discount line" do
    discount_line = template.line_items.detect { |line| line.category == "discount" }
    expect(discount_line).to have_attributes(name: "Pro-rated discount ({unused_days} days)",
                                             amount_expression: "rent * (prorata - 1)", tax_rate: 18)
  end

  context "when the lease has no tax rate" do
    let(:lease) { create(:lease, tax_rate: nil) }

    it "leaves line tax rates nil" do
      expect(template.line_items.map(&:tax_rate)).to all(be_nil)
    end
  end
end
