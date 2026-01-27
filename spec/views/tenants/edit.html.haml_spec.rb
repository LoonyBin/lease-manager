# frozen_string_literal: true

require "rails_helper"

RSpec.describe "tenants/edit" do
  subject { Capybara.string(rendered) }

  before do
    @tenant = assign(:tenant, create(:tenant))
    render
  end

  it { is_expected.to have_selector("form[action='#{tenant_path(@tenant)}'][method='post']") }
  it { is_expected.to have_selector("input[name='tenant[name]']") }
  it { is_expected.to have_selector("input[name='tenant[email]']") }
  it { is_expected.to have_selector("input[name='tenant[phone_number]']") }
end
