# frozen_string_literal: true

require "rails_helper"

RSpec.describe "leases/index" do
  subject { Capybara.string(rendered) }

  let(:property) { create(:property, name: "Prop 1", capacity: 10) }
  let(:tenant) { create(:tenant, name: "Tenant 1") }

  before do
    assign(:leases, Lease.where(id: [
                                  create(:lease, property: property, tenant: tenant, rent_amount: 1000).id,
                                  create(:lease, property: property, tenant: tenant, rent_amount: 1200).id
                                ]).page(1))
    assign(:q, Lease.ransack(nil))
    render
  end

  it { is_expected.to have_css(".resource-item.lease-item", count: 2) }
  it { is_expected.to have_css(".resource-item-title", text: "Prop 1", count: 2) }
  it { is_expected.to have_css(".resource-item-meta", text: "Tenant 1", count: 2) }
  it { is_expected.to have_text("₹1,000") }
  it { is_expected.to have_text("₹1,200") }
end
