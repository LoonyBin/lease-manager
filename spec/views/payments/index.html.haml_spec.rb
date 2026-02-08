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

  it { is_expected.to have_css(".resource-item.payment-item", count: 1) }
  it { is_expected.to have_css(".resource-item-title", text: "₹1,000") }
  it { is_expected.to have_css(".payment-col-tenant .resource-item-text") }
  it { is_expected.to have_css(".payment-col-mode .resource-item-text") }
end
