# frozen_string_literal: true

require "rails_helper"

RSpec.describe "payments/new" do
  subject { Capybara.string(rendered) }

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

  context "when lease_id is pre-populated" do
    let(:lease) { create(:lease) }

    before do
      assign(:payment, Payment.new(lease: lease))
      assign(:leases, [])
      render
    end

    it "does not show the lease select dropdown" do
      expect(subject).not_to have_select("payment[lease_id]")
    end

    it "shows a hidden field with the lease_id" do
      expect(subject).to have_css("input[type='hidden'][name='payment[lease_id]']", visible: :hidden)
    end
  end
end
