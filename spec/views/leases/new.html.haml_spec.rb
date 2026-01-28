# frozen_string_literal: true

require "rails_helper"

RSpec.describe "leases/new" do
  subject { Capybara.string(rendered) }

  before do
    assign(:lease, build(:lease))
    render
  end

  it { is_expected.to have_css("form[action='#{leases_path}'][method='post']") }
  it { is_expected.to have_select("lease[property_id]") }
  it { is_expected.to have_select("lease[tenant_id]") }
  it { is_expected.to have_field("lease[duration_months]") }
  it { is_expected.to have_field("lease[rent_amount]") }
  it { is_expected.to have_field("lease[security_deposit_in_months]") }
end
