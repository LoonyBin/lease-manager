# frozen_string_literal: true

require "rails_helper"

RSpec.describe "properties/new" do
  before do
    assign(:property, build(:property))
  end

  it "renders new property form" do
    render

    assert_select "form[action=?][method=?]", properties_path, "post" do
      assert_select "input[name=?]", "property[name]"
      assert_select "textarea[name=?]", "property[address]"
    end
  end
end
