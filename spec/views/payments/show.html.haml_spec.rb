# frozen_string_literal: true

require "rails_helper"

RSpec.describe "payments/show" do
  subject { rendered }

  before do
    @payment = assign(:payment, create(:payment, amount: 5000))
    render
  end

  it { is_expected.to include("₹5,000") }
  it { is_expected.to have_text(@payment.lease.property.name) }
  it { is_expected.to have_text(@payment.lease.tenant.name) }
  it { is_expected.to include("Allocated To") }
end
