# frozen_string_literal: true

require "rails_helper"

RSpec.describe "properties/edit" do
  subject { Capybara.string(rendered) }

  before do
    @property = assign(:property, create(:property))
    render
  end

  it { is_expected.to have_css("form[action='#{property_path(@property)}'][method='post']") }
  it { is_expected.to have_field("property[name]") }
  it { is_expected.to have_css("textarea[name='property[address]']") }
end
