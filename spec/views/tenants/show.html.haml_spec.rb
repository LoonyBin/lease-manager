# frozen_string_literal: true

require "rails_helper"

RSpec.describe "tenants/show" do
  subject { rendered }

  before do
    @tenant = assign(:tenant, create(:tenant, name: "Name", email: "Email", phone_number: "Phone"))
    render
  end

  it { is_expected.to match(/Name/) }
  it { is_expected.to match(/Email/) }
  it { is_expected.to match(/Phone/) }
end
