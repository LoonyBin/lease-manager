# frozen_string_literal: true

require "rails_helper"

RSpec.describe "leases/index" do
  let(:property) { create(:property, name: "Prop 1") }
  let(:tenant) { create(:tenant, name: "Tenant 1") }

  before do
    assign(:leases, [
             create(:lease, property: property, tenant: tenant, rent_amount: 1000),
             create(:lease, property: property, tenant: tenant, rent_amount: 1200)
           ])
  end

  it "renders a list of leases" do
    render
    assert_select "tr>td", text: "Prop 1", count: 2
    assert_select "tr>td", text: "Tenant 1", count: 2
    assert_select "tr>td", text: "12 months", count: 2
    assert_select "tr>td", text: "$1,000.00", count: 1
    assert_select "tr>td", text: "$1,200.00", count: 1
  end
end
