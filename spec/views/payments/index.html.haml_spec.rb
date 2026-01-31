# frozen_string_literal: true

require "rails_helper"

RSpec.describe "payments/index" do
  subject { Capybara.string(rendered) }

  before do
    invoice = create(:invoice, status: :finalized, number: "INV-001")
    payment = create(:payment, amount: 1000)
    create(:payment_allocation, payment: payment, invoice: invoice, amount: 1000)
    assign(:payments, Payment.where(id: payment.id))
    render
  end

  it { is_expected.to have_css("h2", text: "Payments") }
  it { is_expected.to have_link("Record Payment") }
  it { is_expected.to have_css("th", text: "Date") }
  it { is_expected.to have_css("th", text: "Amount") }
  it { is_expected.to have_css("td", text: "₹1,000.00") }
end
