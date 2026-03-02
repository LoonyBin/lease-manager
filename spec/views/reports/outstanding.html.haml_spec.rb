# frozen_string_literal: true

require "rails_helper"

RSpec.describe "reports/outstanding" do
  subject { Capybara.string(rendered) }

  before do
    invoice = create(:invoice, status: :finalized, number: "INV-001")
    create(:line_item, invoice: invoice, amount: 1000)
    assign(:outstanding_invoices, [invoice])
    assign(:total_outstanding, 1000)
    render
  end

  it { is_expected.to have_css("h2", text: "Outstanding Invoices") }
  it { is_expected.to have_css("th", text: "Property") }
  it { is_expected.to have_css("th", text: "Outstanding") }
  it { is_expected.to have_css(".badge", text: "₹1,000.00") }
  it { is_expected.to have_link("Back to Overview") }
end
