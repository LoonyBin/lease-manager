# frozen_string_literal: true

require "rails_helper"

RSpec.describe "leases/index" do
  subject { Capybara.string(rendered) }

  let(:property) { create(:property, name: "Prop 1") }
  let(:tenant) { create(:tenant, name: "Tenant 1") }

  before do
    assign(:leases, Lease.where(id: [
                                  create(:lease, property: property, tenant: tenant, rent_amount: 1000).id,
                                  create(:lease, property: property, tenant: tenant, rent_amount: 1200).id
                                ]).page(1))
    render
  end

  it { is_expected.to have_css("tr>td", text: "Prop 1", count: 2) }
  it { is_expected.to have_css("tr>td", text: "Tenant 1", count: 2) }
  it { is_expected.to have_css("tr>td", text: "12 months", count: 2) }
  it { is_expected.to have_css("tr>td", text: "₹1,000.00", count: 1) }
  it { is_expected.to have_css("tr>td", text: "₹1,200.00", count: 1) }
end
