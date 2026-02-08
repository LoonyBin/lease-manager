# frozen_string_literal: true

require "rails_helper"

RSpec.describe "properties/index" do
  subject { Capybara.string(rendered) }

  before do
    properties = [
      create(:property, name: "Name 1", address: "Address 1"),
      create(:property, name: "Name 2", address: "Address 2")
    ]
    assign(:properties, Property.where(id: properties.map(&:id)).page(1))
    assign(:q, Property.ransack(nil))
    render
  end

  it { is_expected.to have_css(".resource-item.property-item", count: 2) }
  it { is_expected.to have_css(".resource-item-title", text: "Name 1") }
  it { is_expected.to have_css(".resource-item-title", text: "Name 2") }
  it { is_expected.to have_css(".resource-item-meta", text: "Address 1") }
  it { is_expected.to have_css(".resource-item-meta", text: "Address 2") }
end
