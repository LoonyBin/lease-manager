# frozen_string_literal: true

require "rails_helper"

RSpec.describe "tenants/edit" do
  subject { Capybara.string(rendered) }

  before do
    @tenant = assign(:tenant, create(:tenant))
    render
  end

  it { is_expected.to have_css("form[action='#{tenant_path(@tenant)}'][method='post']") }
  it { is_expected.to have_field("tenant[name]") }
  it { is_expected.to have_field("tenant[email]") }
  it { is_expected.to have_field("tenant[phone_number]") }
end
