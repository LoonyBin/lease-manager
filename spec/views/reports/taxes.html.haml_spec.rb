# frozen_string_literal: true

require "rails_helper"

RSpec.describe "reports/taxes" do
  subject { Capybara.string(rendered) }

  before do
    assign(:taxes_by_month, { Date.new(2025, 1, 1) => 1800, Date.new(2025, 2, 1) => 2160 })
    assign(:total_taxes, 3960)
    render
  end

  it { is_expected.to have_css("h2", text: "Taxes by Month") }
  it { is_expected.to have_css("td", text: "January 2025") }
  it { is_expected.to have_css("td", text: "₹1,800.00") }
  it { is_expected.to have_css(".badge", text: "₹3,960.00") }
  it { is_expected.to have_link("Back to Overview") }
end
