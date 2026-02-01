# frozen_string_literal: true

require "rails_helper"

RSpec.describe "owners/show" do
  subject { Capybara.string(rendered) }

  before do
    owner = create(:owner, name: "John Smith", address: "123 Main St", invoice_sequence: 5)
    property = create(:property, owner: owner, name: "Sunset Villa")
    assign(:owner, owner)
    assign(:properties, [property])
    render
  end

  it { is_expected.to have_css("h1", text: "John Smith") }
  it { is_expected.to have_css("p", text: "123 Main St") }
  it { is_expected.to have_css("p", text: "5") }
  it { is_expected.to have_css("h3", text: "Properties") }
  it { is_expected.to have_link("Sunset Villa") }
  it { is_expected.to have_css("a[aria-label='Edit']") }
end
