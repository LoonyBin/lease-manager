# frozen_string_literal: true

require "rails_helper"

RSpec.describe "invoices/edit" do
  subject { Capybara.string(rendered) }

  before do
    invoice = create(:invoice)
    create(:line_item, invoice: invoice, name: "Rent", amount: 1000)
    assign(:invoice, invoice)
    render
  end

  it { is_expected.to have_css("h2", text: "Edit Invoice") }
  it { is_expected.to have_css("form[method='post']") }
  it { is_expected.to have_field("invoice[date]") }
  it { is_expected.to have_select("invoice[status]") }
  it { is_expected.to have_css("input[value='Rent']") }
  it { is_expected.to have_css("th", text: "Tax Rate (%)") }
  it { is_expected.to have_field("invoice[line_items_attributes][0][tax_rate]") }
  it { is_expected.to have_button("Update Invoice") }
  it { is_expected.to have_button("Add Line Item") }
end
