# frozen_string_literal: true

require "rails_helper"

RSpec.describe "tenants/new" do
  subject { Capybara.string(rendered) }

  before do
    assign(:tenant, build(:tenant))
    render
  end

  it { is_expected.to have_selector("form[action='#{tenants_path}'][method='post']") }
  it { is_expected.to have_selector("input[name='tenant[name]']") }
  it { is_expected.to have_selector("input[name='tenant[email]']") }
  it { is_expected.to have_selector("input[name='tenant[phone_number]']") }
end
