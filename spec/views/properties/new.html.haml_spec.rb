# frozen_string_literal: true

require "rails_helper"

RSpec.describe "properties/new" do
  subject { Capybara.string(rendered) }

  before do
    assign(:property, build(:property))
    render
  end

  it { is_expected.to have_selector("form[action='#{properties_path}'][method='post']") }
  it { is_expected.to have_selector("input[name='property[name]']") }
  it { is_expected.to have_selector("textarea[name='property[address]']") }
end
