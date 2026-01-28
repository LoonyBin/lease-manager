# frozen_string_literal: true

require "rails_helper"

RSpec.describe "owners/new" do
  subject { Capybara.string(rendered) }

  before do
    assign(:owner, Owner.new)
    render
  end

  it { is_expected.to have_css("h2", text: "New Owner") }
  it { is_expected.to have_css("form[action='#{owners_path}'][method='post']") }
  it { is_expected.to have_field("owner[name]") }
  it { is_expected.to have_css("textarea[name='owner[address]']") }
  it { is_expected.to have_button("Create Owner") }
end
