# frozen_string_literal: true

require "rails_helper"

RSpec.describe "tenants/index" do
  subject { Capybara.string(rendered) }

  before do
    tenants = [
      create(:tenant, name: "Name 1", email: "Email 1", phone_number: "Phone 1"),
      create(:tenant, name: "Name 2", email: "Email 2", phone_number: "Phone 2")
    ]
    assign(:tenants, Tenant.where(id: tenants.map(&:id)).page(1))
    assign(:q, Tenant.ransack(nil))
    render
  end

  it { is_expected.to have_css(".resource-item.tenant-item", count: 2) }
  it { is_expected.to have_css(".resource-item-title", text: "Name 1") }
  it { is_expected.to have_css(".resource-item-text", text: "Email 1") }
  it { is_expected.to have_css(".resource-item-meta", text: "Phone 1") }
  it { is_expected.to have_css(".resource-item-title", text: "Name 2") }
  it { is_expected.to have_css(".resource-item-text", text: "Email 2") }
  it { is_expected.to have_css(".resource-item-meta", text: "Phone 2") }
end
