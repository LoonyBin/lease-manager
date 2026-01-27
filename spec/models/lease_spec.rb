# frozen_string_literal: true

require "rails_helper"

RSpec.describe Lease do
  subject(:lease) { build(:lease) }

  describe "associations" do
    it { is_expected.to belong_to(:property) }
    it { is_expected.to belong_to(:tenant) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:start_date) }
    it { is_expected.to validate_presence_of(:rent_amount) }
    it { is_expected.to validate_numericality_of(:rent_amount).is_greater_than(0) }
    it { is_expected.to validate_presence_of(:duration_months) }
    it { is_expected.to validate_numericality_of(:duration_months).only_integer.is_greater_than(0) }
    it { is_expected.to validate_presence_of(:security_deposit_in_months) }

    it do
      is_expected.to validate_numericality_of(:security_deposit_in_months)
        .only_integer
        .is_greater_than_or_equal_to(0)
    end

    it { is_expected.to validate_numericality_of(:enhancement_period_months).only_integer.is_greater_than(0) }

    context "with custom validations" do
      before do
        lease.start_date = "2025-01-01"
        lease.terminated_on = "2024-01-01"
        lease.valid?
      end

      it do
        is_expected.to have_validation_error(:terminated_on)
          .with_message("must be after the start date")
      end
    end
  end

  describe "#end_date" do
    context "when terminated_on is set" do
      subject { build(:lease, start_date: "2025-01-01", duration_months: 12, terminated_on: "2025-06-01") }

      its(:end_date) { is_expected.to eq(Date.new(2025, 6, 1)) }
    end

    context "when terminated_on is nil" do
      subject { build(:lease, start_date: "2025-01-16", duration_months: 12) }

      its(:end_date) { is_expected.to eq(Date.new(2025, 12, 31)) }
    end
  end

  describe "#security_deposit" do
    subject { build(:lease, rent_amount: 1000, security_deposit_in_months: 2) }

    its(:security_deposit) { is_expected.to eq(2000.0) }
  end

  describe "#current_rent_at" do
    subject { lease }

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
