# frozen_string_literal: true

require "rails_helper"

RSpec.describe "owners/edit" do
  subject { Capybara.string(rendered) }

  before do
    assign(:owner, create(:owner, name: "John Smith"))
    render
  end

  it { is_expected.to have_css("h2", text: "Edit Owner") }
  it { is_expected.to have_css("form[method='post']") }
  it { is_expected.to have_css("input[name='owner[name]'][value='John Smith']") }
  it { is_expected.to have_button("Update Owner") }
end
