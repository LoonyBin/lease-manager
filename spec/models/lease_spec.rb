# frozen_string_literal: true

require "rails_helper"

RSpec.describe Lease do
  subject(:lease) { build(:lease) }

  describe "associations" do
    it { is_expected.to belong_to(:property) }
    it { is_expected.to belong_to(:tenant) }
    it { is_expected.to belong_to(:renewed_from).class_name("Lease").optional }
    it { is_expected.to have_one(:renewal).class_name("Lease").with_foreign_key(:renewed_from_id) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:start_date) }
    it { is_expected.to validate_presence_of(:rent_amount) }
    it { is_expected.to validate_numericality_of(:rent_amount).is_greater_than(0) }
    it { is_expected.to validate_presence_of(:duration_months) }
    it { is_expected.to validate_numericality_of(:duration_months).only_integer.is_greater_than(0) }
    it { is_expected.to validate_presence_of(:enhancement_period_months) }
    it { is_expected.to validate_numericality_of(:enhancement_period_months).only_integer.is_greater_than(0) }
    it { is_expected.to validate_numericality_of(:enhancement_amount).is_greater_than_or_equal_to(0).allow_nil }

    it do
      expect(lease).to validate_numericality_of(:tax_rate)
        .is_greater_than_or_equal_to(0)
        .is_less_than_or_equal_to(100)
        .allow_nil
    end

    it { is_expected.to validate_presence_of(:quantity) }
    it { is_expected.to validate_numericality_of(:quantity).only_integer.is_greater_than(0) }
    it { is_expected.to have_many_attached(:documents) }

    describe "#quantity_within_capacity" do
      let(:property) { create(:property, capacity: 10) }
      let(:lease) { build(:lease, property: property, quantity: 11, start_date: Date.current) }

      it "is invalid if quantity exceeds capacity" do
        aggregate_failures do
          expect(lease).not_to be_valid
          expect(lease.errors[:quantity])
            .to include("exceeds available capacity of 10 Units during the lease period")
        end
      end

      it "is valid if quantity is within capacity" do
        lease.quantity = 10
        expect(lease).to be_valid
      end

      it "considers existing leases with overlapping future lease" do # rubocop:disable RSpec/ExampleLength
        create(:lease, property: property, quantity: 5, start_date: 6.months.from_now, duration_months: 6)

        lease.quantity = 6
        lease.duration_months = 12

        aggregate_failures do
          expect(lease).not_to be_valid
          expect(lease.errors[:quantity])
            .to include("exceeds available capacity of 5 Units during the lease period")
        end
      end
    end

    describe "#termination_date_after_start_date" do
      let(:lease) { build(:lease, start_date: Time.zone.today, terminated_on: Date.yesterday) }

      it "is invalid" do
        expect(lease).not_to be_valid
      end

      it "has correct error message" do
        lease.valid?
        expect(lease.errors[:terminated_on]).to include("must be after the start date")
      end
    end
  end

  describe "#property_schedule default" do
    let(:property) { create(:property, name: "Sunset Villa", address: "123 Main St") }

    it "defaults to property name and address" do
      lease = create(:lease, property: property)
      expect(lease.property_schedule).to eq("Sunset Villa, 123 Main St")
    end

    it "does not overwrite an explicit value" do
      lease = create(:lease, property: property, property_schedule: "Custom schedule")
      expect(lease.property_schedule).to eq("Custom schedule")
    end

    it "handles property without address" do
      no_address_property = create(:property, name: "Sunset Villa", address: nil)
      lease = create(:lease, property: no_address_property)
      expect(lease.property_schedule).to eq("Sunset Villa")
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
    context "with months type" do
      subject { build(:lease, rent_amount: 1000, security_deposit_value: 2, security_deposit_type: :months) }

      its(:security_deposit) { is_expected.to eq(2000.0) }
    end

    context "with fixed type" do
      subject { build(:lease, rent_amount: 1000, security_deposit_value: 50_000, security_deposit_type: :fixed) }

      its(:security_deposit) { is_expected.to eq(50_000) }
    end
  end

  describe "#current_rent_at" do
    subject { lease }

    let(:lease) do
      create(:lease,
             start_date: Date.new(2023, 1, 16),
             rent_amount: 1000,
             enhancement_period_months: 12,
             enhancement_amount: 5.0,
             enhancement_type: :percentage)
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
      lease.update(enhancement_type: :fixed, enhancement_amount: 100)
      expect(lease.current_rent_at(Date.new(2024, 1, 1))).to eq(1100)
    end
  end

  describe ".build_renewal" do
    let(:old_lease) do
      create(:lease,
             start_date: Date.new(2024, 1, 1),
             duration_months: 12,
             rent_amount: 1000,
             enhancement_period_months: 12,
             enhancement_amount: 5,
             enhancement_type: :percentage,
             tax_name: "GST",
             tax_rate: 18)
    end

    let(:new_lease) { described_class.build_renewal(old_lease) }

    it "copies property and tenant" do
      expect(new_lease).to have_attributes(property_id: old_lease.property_id, tenant_id: old_lease.tenant_id)
    end

    it "sets start date to day after old lease ends" do
      expect(new_lease.start_date).to eq(old_lease.end_date + 1.day)
    end

    it "calculates enhanced rent amount" do
      expect(new_lease.rent_amount).to eq(1050.0) # 1000 + 5%
    end

    it "links to old lease" do
      expect(new_lease.renewed_from).to eq(old_lease)
    end

    it "copies property_schedule from old lease" do
      old_lease.update!(property_schedule: "Custom property schedule text")
      expect(new_lease.property_schedule).to eq("Custom property schedule text")
    end

    it "does not persist the new lease" do
      expect(new_lease).not_to be_persisted
    end
  end

  describe "after_create callback" do
    let(:old_lease) do
      create(:lease,
             start_date: Date.new(2024, 1, 1),
             duration_months: 12,
             rent_amount: 1000)
    end

    it "terminates the old lease when creating a renewal" do
      new_lease = described_class.build_renewal(old_lease)
      new_lease.save!

      expect(old_lease.reload.terminated_on).to eq(new_lease.start_date - 1.day)
    end

    it "does not affect other leases when not a renewal" do
      regular_lease = create(:lease)
      expect(regular_lease.terminated_on).to be_nil
    end
  end
end
