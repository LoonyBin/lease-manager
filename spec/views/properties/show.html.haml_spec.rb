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

  context "create shortcut dropdown" do
    subject { Capybara.string(rendered) }

    it "renders the + dropdown button" do
      expect(subject).to have_css(".dropdown")
    end

    it "includes a New Lease link" do
      expect(subject).to have_link("New Lease")
    end
  end
end
