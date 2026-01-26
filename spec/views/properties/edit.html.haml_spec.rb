# frozen_string_literal: true

require "rails_helper"

RSpec.describe "properties/edit" do
  before do
    @property = assign(:property, create(:property))
  end

  it "renders the edit property form" do
    render

    assert_select "form[action=?][method=?]", property_path(@property), "post" do
      assert_select "input[name=?]", "property[name]"
      assert_select "textarea[name=?]", "property[address]"
    end
  end
end
