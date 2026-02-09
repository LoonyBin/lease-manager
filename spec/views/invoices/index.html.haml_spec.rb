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

  it { is_expected.to have_css(".resource-item.invoice-item", count: 1) }
  it { is_expected.to have_css(".invoice-item-total", text: "₹1,000") }
  it { is_expected.to have_css(".resource-item.invoice-item[data-controller='clickable-row']") }
  it { is_expected.to have_css(".invoice-col-property .resource-item-meta") }
  it { is_expected.to have_css(".invoice-col-tenant .resource-item-meta") }
end
