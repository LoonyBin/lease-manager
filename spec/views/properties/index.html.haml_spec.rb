# frozen_string_literal: true

require "rails_helper"

RSpec.describe "properties/index" do
  before do
    assign(:properties, [
             create(:property, name: "Name 1", address: "Address 1"),
             create(:property, name: "Name 2", address: "Address 2")
           ])
  end

  it "renders a list of properties" do
    render
    assert_select "tr>td", text: "Name 1", count: 1
    assert_select "tr>td", text: "Address 1", count: 1
    assert_select "tr>td", text: "Name 2", count: 1
    assert_select "tr>td", text: "Address 2", count: 1
  end
end
