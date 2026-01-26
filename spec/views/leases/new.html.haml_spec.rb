# frozen_string_literal: true

require "rails_helper"

RSpec.describe "leases/new" do
  before do
    assign(:lease, build(:lease))
  end

  it "renders new lease form" do
    render

    assert_select "form[action=?][method=?]", leases_path, "post" do
      assert_select "select[name=?]", "lease[property_id]"
      assert_select "select[name=?]", "lease[tenant_id]"
      assert_select "input[name=?]", "lease[duration_months]"
      assert_select "input[name=?]", "lease[rent_amount]"
      assert_select "input[name=?]", "lease[security_deposit_in_months]"
    end
  end
end
