# frozen_string_literal: true

require "rails_helper"

RSpec.describe "properties/index" do
  subject { Capybara.string(rendered) }

  before do
    properties = [
      create(:property, name: "Name 1", address: "Address 1"),
      create(:property, name: "Name 2", address: "Address 2")
    ]
    assign(:properties, Property.where(id: properties.map(&:id)))
    render
  end

  it { is_expected.to have_css("tr>td", text: "Name 1", count: 1) }
  it { is_expected.to have_css("tr>td", text: "Address 1", count: 1) }
  it { is_expected.to have_css("tr>td", text: "Name 2", count: 1) }
  it { is_expected.to have_css("tr>td", text: "Address 2", count: 1) }
end
