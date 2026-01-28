# frozen_string_literal: true

require "rails_helper"

RSpec.describe "reports/index" do
  subject { Capybara.string(rendered) }

  before do
    assign(:total_revenue, 50_000)
    assign(:total_outstanding, 10_000)
    assign(:total_taxes, 5_000)
    assign(:total_collected, 40_000)
    render
  end

  it { is_expected.to have_css("h1", text: "Financial Reports") }
  it { is_expected.to have_css("h2", text: "Total Revenue") }
  it { is_expected.to have_css("p", text: "₹50,000.00") }
  it { is_expected.to have_css("h2", text: "Outstanding") }
  it { is_expected.to have_css("p", text: "₹10,000.00") }
  it { is_expected.to have_link("View Details", count: 3) }
end
