# frozen_string_literal: true

require "rails_helper"

RSpec.describe "leases/show" do
  subject { rendered }

  before do
    @lease = assign(:lease, create(:lease))
    render
  end

  it { is_expected.to match(/#{@lease.property.name}/) }
  it { is_expected.to match(/#{@lease.tenant.name}/) }
  it { is_expected.to match(/12 months/) }
  it { is_expected.to match(/₹1,000/) }
end
