# frozen_string_literal: true

require "rails_helper"

RSpec.describe "payments/new" do
  subject { Capybara.string(rendered) }

  context "with a new payment" do
    before do
      assign(:payment, Payment.new)
      assign(:leases, [create(:lease)])
      render
    end

    it { is_expected.to have_css("h2", text: "Record Payment") }
    it { is_expected.to have_css("form[action='#{payments_path}'][method='post']") }
    it { is_expected.to have_select("payment[lease_id]") }
    it { is_expected.to have_field("payment[date]") }
    it { is_expected.to have_field("payment[amount]") }
    it { is_expected.to have_button("Create Payment") }
  end

  context "when lease_id is pre-populated" do
    let(:lease) { create(:lease) }

    before do
      assign(:payment, Payment.new(lease: lease))
      assign(:leases, [])
      render
    end

    it "does not show the lease select dropdown" do
      is_expected.to have_no_select("payment[lease_id]")
    end

    it "shows a hidden field with the lease_id" do
      is_expected.to have_field("payment[lease_id]", type: "hidden", visible: :hidden)
    end
  end
end
