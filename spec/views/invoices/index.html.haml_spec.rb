# frozen_string_literal: true

require "rails_helper"

RSpec.describe "invoices/index" do
  subject { Capybara.string(rendered) }

  before do
    invoice = create(:invoice)
    create(:line_item, invoice: invoice, amount: 1000)
    assign(:invoices, Invoice.where(id: invoice.id).page(1))
    assign(:q, Invoice.ransack(nil))
    render
  end

  it { is_expected.to have_css("h2", text: "Invoices") }
  it { is_expected.to have_css("th", text: "Date") }
  it { is_expected.to have_css("th", text: "Amount") }
  it { is_expected.to have_css("td", text: "₹1,000.00") }
  it { is_expected.to have_css("tr[data-controller='clickable-row']") }
end
