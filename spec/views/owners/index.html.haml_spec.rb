# frozen_string_literal: true

require "rails_helper"

RSpec.describe "owners/index" do
  subject { Capybara.string(rendered) }

  before do
    owner = create(:owner, name: "John Smith", address: "123 Main St")
    create(:property, owner: owner)
    assign(:owners, Owner.where(id: owner.id).page(1))
    render
  end

  it { is_expected.to have_css("h1", text: "Owners") }
  it { is_expected.to have_link("New Owner") }
  it { is_expected.to have_css("th", text: "Name") }
  it { is_expected.to have_css("th", text: "Address") }
  it { is_expected.to have_link("John Smith") }
  it { is_expected.to have_css("td", text: "123 Main St") }
  it { is_expected.to have_css("a[aria-label='Edit John Smith']") }
end
