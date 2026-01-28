# frozen_string_literal: true

require "rails_helper"

RSpec.describe "properties/new" do
  subject { Capybara.string(rendered) }

  before do
    assign(:property, Property.new)
    render
  end

  it { is_expected.to have_css("form[action='#{properties_path}'][method='post']") }
  it { is_expected.to have_field("property[name]") }
  it { is_expected.to have_css("textarea[name='property[address]']") }
end
