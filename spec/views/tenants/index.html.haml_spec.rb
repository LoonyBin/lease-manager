# frozen_string_literal: true

require "rails_helper"

RSpec.describe "tenants/index" do
  subject { Capybara.string(rendered) }

  before do
    tenants = [
      create(:tenant, name: "Name 1", email: "Email 1", phone_number: "Phone 1"),
      create(:tenant, name: "Name 2", email: "Email 2", phone_number: "Phone 2")
    ]
    assign(:tenants, Tenant.where(id: tenants.map(&:id)))
    render
  end

  it { is_expected.to have_css("tr>td", text: "Name 1", count: 1) }
  it { is_expected.to have_css("tr>td", text: "Email 1", count: 1) }
  it { is_expected.to have_css("tr>td", text: "Phone 1", count: 1) }
  it { is_expected.to have_css("tr>td", text: "Name 2", count: 1) }
  it { is_expected.to have_css("tr>td", text: "Email 2", count: 1) }
  it { is_expected.to have_css("tr>td", text: "Phone 2", count: 1) }
end
