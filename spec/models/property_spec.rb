# frozen_string_literal: true

require "rails_helper"

RSpec.describe Property do
  subject { build(:property) }

  describe "associations" do
    it { is_expected.to belong_to(:owner) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:address) }
    it { is_expected.to validate_presence_of(:capacity) }
    it { is_expected.to validate_numericality_of(:capacity).only_integer.is_greater_than(0) }
    it { is_expected.to validate_presence_of(:unit) }
  end

  describe "#available_capacity" do
    let(:property) { create(:property, capacity: 10) }

    it "returns total capacity when no leases exist" do
      expect(property.available_capacity).to eq(10)
    end

    it "subtracts quantity of active leases" do
      create(:lease, property: property, quantity: 4, start_date: Date.current, duration_months: 12)
      create(:lease, property: property, quantity: 2, start_date: Date.current, duration_months: 12)

      expect(property.available_capacity).to eq(4)
    end

    it "ignores terminated leases" do
      create(:lease, property: property, quantity: 4, start_date: 1.month.ago, duration_months: 12,
                     terminated_on: Date.yesterday)
      expect(property.available_capacity).to eq(10)
    end

    it "ignores future leases" do
      create(:lease, property: property, quantity: 4, start_date: 1.month.from_now, duration_months: 12)
      expect(property.available_capacity).to eq(10)
    end
  end
end
