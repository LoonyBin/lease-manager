# frozen_string_literal: true

require "rails_helper"

RSpec.describe "leases/edit" do
  subject { Capybara.string(rendered) }

  before do
    @lease = assign(:lease, create(:lease))
    render
  end

  it { is_expected.to have_selector("form[action='#{lease_path(@lease)}'][method='post']") }
  it { is_expected.to have_selector("select[name='lease[property_id]']") }
  it { is_expected.to have_selector("select[name='lease[tenant_id]']") }
  it { is_expected.to have_selector("input[name='lease[duration_months]']") }
  it { is_expected.to have_selector("input[name='lease[rent_amount]']") }
  it { is_expected.to have_selector("input[name='lease[security_deposit_in_months]']") }
end
