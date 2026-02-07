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

  it { is_expected.to have_css(".payment-item", count: 1) }
  it { is_expected.to have_css(".payment-item-amount", text: "₹1,000") }
  it { is_expected.to have_css(".payment-item-tenant") }
  it { is_expected.to have_css(".payment-item-mode") }
end
