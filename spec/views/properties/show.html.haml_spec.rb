# frozen_string_literal: true

require "rails_helper"

RSpec.describe "properties/show" do
  before do
    @property = assign(:property, create(:property, name: "Name", address: "MyText"))
  end

  it "renders attributes in <p>" do
    render
    expect(rendered).to match(/Name/)
    expect(rendered).to match(/MyText/)
  end
end
