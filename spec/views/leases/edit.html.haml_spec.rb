# frozen_string_literal: true

require "rails_helper"

RSpec.describe "leases/edit" do
  before do
    @lease = assign(:lease, create(:lease))
  end

  it "renders the edit lease form" do
    render

    assert_select "form[action=?][method=?]", lease_path(@lease), "post" do
      assert_select "select[name=?]", "lease[property_id]"
      assert_select "select[name=?]", "lease[tenant_id]"
      assert_select "input[name=?]", "lease[duration_months]"
      assert_select "input[name=?]", "lease[rent_amount]"
      assert_select "input[name=?]", "lease[security_deposit_in_months]"
    end
  end
end
