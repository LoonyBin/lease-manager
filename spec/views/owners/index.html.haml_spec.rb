# frozen_string_literal: true

require "rails_helper"

RSpec.describe "owners/index" do
  subject { Capybara.string(rendered) }

  before do
    owner = create(:owner, name: "John Smith", address: "123 Main St")
    create(:property, owner: owner)
    assign(:owners, Owner.where(id: owner.id).page(1))
    assign(:q, Owner.ransack(nil))
    render
  end

  it { is_expected.to have_css(".resource-item.owner-item", count: 1) }
  it { is_expected.to have_css(".resource-list-header.owner-list-header .owner-col-name", text: "Name") }
  it { is_expected.to have_css(".resource-list-header.owner-list-header .owner-col-address", text: "Address") }
  it { is_expected.to have_link("John Smith") }
  it { is_expected.to have_css(".resource-item-meta", text: "123 Main St") }
  it { is_expected.to have_css("a[aria-label='Edit John Smith']") }
end
