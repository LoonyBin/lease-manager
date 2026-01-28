# frozen_string_literal: true

require "rails_helper"

RSpec.describe "tenants/new" do
  subject { Capybara.string(rendered) }

  before do
    assign(:tenant, Tenant.new)
    render
  end

  it { is_expected.to have_css("form[action='#{tenants_path}'][method='post']") }
  it { is_expected.to have_field("tenant[name]") }
  it { is_expected.to have_field("tenant[email]") }
  it { is_expected.to have_field("tenant[phone_number]") }
end
