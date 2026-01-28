# frozen_string_literal: true

require "rails_helper"

RSpec.describe "reports/revenue" do
  subject { Capybara.string(rendered) }

  before do
    property = create(:property, name: "Sunset Villa")
    assign(:invoices_by_month, { Date.new(2025, 1, 1) => 10_000, Date.new(2025, 2, 1) => 12_000 })
    assign(:invoices_by_property, { property => 22_000 })
    render
  end

  it { is_expected.to have_css("h1", text: "Revenue Report") }
  it { is_expected.to have_css("h2", text: "Revenue by Month") }
  it { is_expected.to have_css("td", text: "January 2025") }
  it { is_expected.to have_css("td", text: "₹10,000.00") }
  it { is_expected.to have_css("h2", text: "Revenue by Property") }
  it { is_expected.to have_css("td", text: "Sunset Villa") }
  it { is_expected.to have_link("← Back to Reports") }
end
