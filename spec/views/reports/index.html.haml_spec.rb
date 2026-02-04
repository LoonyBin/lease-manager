# frozen_string_literal: true

require "rails_helper"

RSpec.describe "reports/index" do
  subject { Capybara.string(rendered) }

  before do
    assign(:total_revenue, 50_000)
    assign(:total_outstanding, 10_000)
    assign(:total_taxes, 5_000)
    assign(:total_collected, 40_000)
    assign(:revenue_by_month, { "Jan 2026" => 10_000, "Feb 2026" => 15_000 })
    assign(:payments_by_month, { "Jan 2026" => 8_000, "Feb 2026" => 12_000 })
    assign(:occupancy_stats, { "Occupied" => 5, "Vacant" => 2 })
    assign(:invoice_status_distribution, { "Paid" => 10, "Sent" => 5 })
    render
  end

  it { is_expected.to have_css("h1", text: "Financial Dashboard") }
  it { is_expected.to have_css("h2", text: "Total Revenue") }
  it { is_expected.to have_css("p", text: "₹50,000.00") }
  it { is_expected.to have_css("h2", text: "Outstanding") }
  it { is_expected.to have_css("p", text: "₹10,000.00") }
  it { is_expected.to have_link("View Details", count: 3) }
end
