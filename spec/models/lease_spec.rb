# frozen_string_literal: true

require "rails_helper"

RSpec.describe Lease do
  describe "validations" do
    it "is valid with valid attributes" do
      lease = build(:lease)
      expect(lease).to be_valid
    end

    it "is invalid without a property" do
      lease = build(:lease, property: nil)
      expect(lease).not_to be_valid
    end

    it "is invalid without a tenant" do
      lease = build(:lease, tenant: nil)
      expect(lease).not_to be_valid
    end

    it "is invalid without a start date" do
      lease = build(:lease, start_date: nil)
      expect(lease).not_to be_valid
      expect(lease.errors[:start_date]).to include("can't be blank")
    end

    it "is invalid without duration_months" do
      lease = build(:lease, duration_months: nil)
      expect(lease).not_to be_valid
      expect(lease.errors[:duration_months]).to include("can't be blank")
    end

    it "is invalid with negative rent" do
      lease = build(:lease, rent_amount: -100)
      expect(lease).not_to be_valid
    end

    it "is invalid if terminated_on is before start_date" do
      lease = build(:lease, start_date: "2025-01-01", terminated_on: "2024-01-01")
      expect(lease).not_to be_valid
      expect(lease.errors[:terminated_on]).to include("must be after the start date")
    end
  end

  describe "#end_date" do
    it "calculates end date from start date and duration" do
      lease = build(:lease, start_date: "2025-01-16", duration_months: 12)
      expect(lease.end_date).to eq(Date.new(2025, 12, 31))
    end

    it "returns termination date if set" do
      lease = build(:lease, start_date: "2025-01-01", duration_months: 12, terminated_on: "2025-06-01")
      expect(lease.end_date).to eq(Date.new(2025, 6, 1))
    end
  end

  describe "#security_deposit" do
    it "calculates security deposit based on rent and months" do
      lease = build(:lease, rent_amount: 1000, security_deposit_in_months: 2)
      expect(lease.security_deposit).to eq(2000.0)
    end
  end

  describe "#current_rent_at" do
    let(:lease) do
      create(:lease,
             start_date: Date.new(2023, 1, 16),
             rent_amount: 1000,
             enhancement_period_months: 12,
             enhancement_percentage: 5.0,
             enhancement_fixed_amount: 0.0)
    end

    it "returns base rent for the first period" do
      expect(lease.current_rent_at(Date.new(2023, 6, 1))).to eq(1000)
    end

    it "increases by percentage after one period" do
      # Jan 1 2024 is exactly 12 months later
      expect(lease.current_rent_at(Date.new(2024, 1, 1))).to eq(1050) # 1000 + 5%
    end

    it "increases compounded for subsequent periods" do
      # Jan 1 2025 is 24 months later (2 periods)
      # 1050 + 5% = 1102.5
      expect(lease.current_rent_at(Date.new(2025, 1, 1))).to eq(1102.5)
    end

    it "handles fixed amount enhancement" do
      lease.update(enhancement_percentage: 0, enhancement_fixed_amount: 100)
      expect(lease.current_rent_at(Date.new(2024, 1, 1))).to eq(1100)
    end
  end
end
