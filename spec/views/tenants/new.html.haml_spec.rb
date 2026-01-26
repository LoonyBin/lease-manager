# frozen_string_literal: true

require "rails_helper"

RSpec.describe "tenants/new" do
  before do
    assign(:tenant, build(:tenant))
  end

  it "renders new tenant form" do
    render

    assert_select "form[action=?][method=?]", tenants_path, "post" do
      assert_select "input[name=?]", "tenant[name]"
      assert_select "input[name=?]", "tenant[email]"
      assert_select "input[name=?]", "tenant[phone_number]"
    end
  end
end
