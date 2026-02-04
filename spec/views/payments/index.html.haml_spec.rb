# frozen_string_literal: true

require "rails_helper"

RSpec.describe "payments/index" do
  subject { Capybara.string(rendered) }

  before do
    payment = create(:payment, amount: 1000)
    assign(:payments, Payment.where(id: payment.id).page(1))
    assign(:q, Payment.ransack(nil))
    render
  end

  it { is_expected.to have_css("h2", text: "Payments") }
  it { is_expected.to have_link("Record Payment") }
  it { is_expected.to have_css("th", text: "Date") }
  it { is_expected.to have_css("th", text: "Amount") }
  it { is_expected.to have_css("td", text: "₹1,000.00") }
end
