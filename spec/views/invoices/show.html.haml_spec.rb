# frozen_string_literal: true

require "rails_helper"

RSpec.describe "invoices/show" do
  subject { Capybara.string(rendered) }

  before do
    invoice = create(:invoice)
    create(:line_item, invoice: invoice, name: "Rent", amount: 1000, category: "rent")
    assign(:invoice, invoice)
    render
  end

  it { is_expected.to have_css("h2", text: "Invoice") }
  it { is_expected.to have_css("th", text: "Description") }
  it { is_expected.to have_css("td", text: "Rent") }
  it { is_expected.to have_css("td", text: "₹1,000.00") }
  it { is_expected.to have_link("Edit") }
  it { is_expected.to have_link("Back") }
end
