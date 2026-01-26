# frozen_string_literal: true

require "rails_helper"

RSpec.describe "tenants/edit" do
  before do
    @tenant = assign(:tenant, create(:tenant))
  end

  it "renders the edit tenant form" do
    render

    assert_select "form[action=?][method=?]", tenant_path(@tenant), "post" do
      assert_select "input[name=?]", "tenant[name]"
      assert_select "input[name=?]", "tenant[email]"
      assert_select "input[name=?]", "tenant[phone_number]"
    end
  end
end
