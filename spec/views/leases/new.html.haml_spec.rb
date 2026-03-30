# frozen_string_literal: true

require "rails_helper"

RSpec.describe "leases/new" do
  subject { Capybara.string(rendered) }

  context "with a new lease" do
    before do
      assign(:lease, build(:lease))
      render
    end

    it { is_expected.to have_css("form[action='#{leases_path}'][method='post']") }
    it { is_expected.to have_select("lease[property_id]") }
    it { is_expected.to have_select("lease[tenant_id]") }
    it { is_expected.to have_field("lease[duration_months]") }
    it { is_expected.to have_field("lease[rent_amount]") }
    it { is_expected.to have_field("lease[security_deposit_value]") }
  end

  context "when property_id is pre-populated" do
    let(:property) { create(:property) }

    before do
      assign(:lease, Lease.new(property: property))
      render
    end

    it "does not show the property select dropdown" do
      is_expected.to have_no_select("lease[property_id]")
    end

    it "shows a hidden field with the property_id" do
      is_expected.to have_field("lease[property_id]", type: "hidden", visible: :hidden)
    end
  end
end
