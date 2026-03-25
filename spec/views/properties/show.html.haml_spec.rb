# frozen_string_literal: true

require "rails_helper"

RSpec.describe "properties/show" do
  subject { rendered }

  before do
    @property = assign(:property, create(:property, name: "Name", address: "MyText"))
    render
  end

  it { is_expected.to match(/Name/) }
  it { is_expected.to match(/MyText/) }

  context "with create shortcut dropdown" do
    subject { Capybara.string(view.content_for(:page_actions)) }

    it "renders the + dropdown button" do
      is_expected.to have_css(".dropdown")
    end

    it "includes a New Lease link" do
      is_expected.to have_link("New Lease")
    end
  end
end
