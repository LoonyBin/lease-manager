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

    it "subtracts quantity of active leases at single date" do
      create(:lease, property: property, quantity: 4, start_date: Date.current, duration_months: 12)
      expect(property.available_capacity).to eq(6)
    end

    it "finds minimum availability over a duration" do
      # Lease 1: Jan - Dec, Qty 4
      create(:lease, property: property, quantity: 4, start_date: Date.new(2025, 1, 1), duration_months: 12)
      # Lease 2: June - Dec, Qty 3
      create(:lease, property: property, quantity: 3, start_date: Date.new(2025, 6, 1), duration_months: 7)

      # Check Jan (only Lease 1) -> 6 available
      expect(property.available_capacity(Date.new(2025, 1, 1), Date.new(2025, 1, 31))).to eq(6)

      # Check June (Lease 1 + Lease 2) -> 3 available
      expect(property.available_capacity(Date.new(2025, 6, 1), Date.new(2025, 6, 30))).to eq(3)

      # Check Range Jan - Dec -> Min availability is 3 (in June)
      expect(property.available_capacity(Date.new(2025, 1, 1), Date.new(2025, 12, 31))).to eq(3)
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
