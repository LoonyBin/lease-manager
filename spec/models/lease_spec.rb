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

    it { is_expected.to validate_presence_of(:payment_due_in) }

    it "is valid with payment_due_in of 0.days" do
      lease = build(:lease, payment_due_in: 0.days)
      expect(lease).to be_valid
    end

    it "is valid with payment_due_in as a multi-part duration" do
      lease = build(:lease, payment_due_in: 1.month + 9.days)
      expect(lease).to be_valid
    end

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

      it "is invalid when overlapping lease reduces available capacity", :aggregate_failures do
        create(:lease, property: property, quantity: 5, start_date: 6.months.from_now, duration_months: 6)
        lease.assign_attributes(quantity: 6, duration_months: 12)

        expect(lease).not_to be_valid
        expect(lease.errors[:quantity])
          .to include("exceeds available capacity of 5 Units during the lease period")
      end
    end

    describe "enhancement_amount with :inherit type" do
      it "is valid when inherit? and enhancement_amount is nil" do
        parent = create(:lease)
        lease = build(:lease, enhancement_type: :inherit, enhancement_amount: nil, renewed_from: parent)
        expect(lease).to be_valid
      end

      it "is invalid when percentage? and enhancement_amount is nil" do
        lease = build(:lease, enhancement_type: :percentage, enhancement_amount: nil)
        # nil passes allow_nil, so check the numericality does not reject nil
        expect(lease).to be_valid
      end
    end

    describe ":inherit requires renewed_from" do
      it "is invalid when inherit? and renewed_from is absent" do
        lease = build(:lease, enhancement_type: :inherit, enhancement_amount: nil, renewed_from: nil)
        expect(lease).not_to be_valid
      end

      it "sets an error on renewed_from when inherit? and renewed_from is absent" do
        lease = build(:lease, enhancement_type: :inherit, enhancement_amount: nil, renewed_from: nil)
        lease.valid?
        expect(lease.errors[:renewed_from]).to be_present
      end

      it "is valid when inherit? and renewed_from is present" do
        parent = create(:lease)
        lease = build(:lease, enhancement_type: :inherit, enhancement_amount: nil, renewed_from: parent)
        expect(lease).to be_valid
      end

      it "does not require renewed_from when percentage?" do
        lease = build(:lease, enhancement_type: :percentage, renewed_from: nil)
        lease.valid?
        expect(lease.errors[:renewed_from]).to be_empty
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

    context "with :inherit type" do
      let(:root_lease) do
        create(:lease,
               start_date: Date.new(2023, 1, 1),
               rent_amount: 1000,
               enhancement_period_months: 12,
               enhancement_amount: 10.0,
               enhancement_type: :percentage)
      end

      let(:child_lease) do
        build(:lease,
              start_date: Date.new(2023, 12, 1),
              rent_amount: 1100,
              enhancement_period_months: 12,
              enhancement_amount: nil,
              enhancement_type: :inherit,
              renewed_from: root_lease).tap(&:save!)
      end

      let(:grandchild_lease) do
        build(:lease,
              start_date: Date.new(2024, 11, 1),
              rent_amount: 1210,
              enhancement_period_months: 12,
              enhancement_amount: nil,
              enhancement_type: :inherit,
              renewed_from: child_lease).tap(&:save!)
      end

      it "delegates to parent lease" do
        expect(child_lease.current_rent_at(Date.new(2024, 1, 1))).to eq(1100)
      end

      it "delegates through the chain (grandparent)" do
        expect(grandchild_lease.current_rent_at(Date.new(2025, 1, 1))).to eq(1210.0)
      end

      it "delegates mid-period through the chain" do
        expect(grandchild_lease.current_rent_at(Date.new(2024, 3, 1))).to eq(1100)
      end

      it "falls back to rent_amount when renewed_from is absent" do
        orphan = build(:lease, enhancement_type: :inherit, enhancement_amount: nil, renewed_from: nil)
        # bypass the validation to test the guard in current_rent_at
        allow(orphan).to receive(:renewed_from).and_return(nil)
        expect(orphan.current_rent_at(orphan.start_date)).to eq(orphan.rent_amount)
      end
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

    it "sets enhancement_type to :inherit" do
      expect(new_lease.enhancement_type).to eq("inherit")
    end

    it "clears enhancement_amount" do
      expect(new_lease.enhancement_amount).to be_nil
    end
  end

  describe ".by_status" do
    let!(:active_lease) do
      create(:lease, start_date: 1.month.ago.to_date, duration_months: 12)
    end
    let!(:upcoming_lease) do
      create(:lease, start_date: 1.month.from_now.to_date, duration_months: 12)
    end
    let!(:expired_lease) do
      create(:lease, start_date: 2.years.ago.to_date, duration_months: 6)
    end
    let!(:terminated_lease) do
      create(:lease, start_date: 6.months.ago.to_date, duration_months: 12,
                     terminated_on: 3.months.ago.to_date)
    end
    let!(:archived_lease) do
      create(:lease, start_date: 6.months.ago.to_date, duration_months: 12,
                     terminated_on: 3.months.ago.to_date, archived_at: 1.month.ago)
    end

    describe "active" do
      subject { described_class.by_status("active") }

      it { is_expected.to include(active_lease) }
      it { is_expected.not_to include(upcoming_lease) }
      it { is_expected.not_to include(expired_lease) }
      it { is_expected.not_to include(terminated_lease) }
    end

    describe "upcoming" do
      subject { described_class.by_status("upcoming") }

      it { is_expected.to include(upcoming_lease) }
      it { is_expected.not_to include(active_lease) }
      it { is_expected.not_to include(expired_lease) }
      it { is_expected.not_to include(terminated_lease) }
    end

    describe "expired" do
      subject { described_class.by_status("expired") }

      it { is_expected.to include(expired_lease) }
      it { is_expected.not_to include(active_lease) }
      it { is_expected.not_to include(upcoming_lease) }
      it { is_expected.not_to include(terminated_lease) }
    end

    describe "terminated" do
      subject { described_class.by_status("terminated") }

      it { is_expected.to include(terminated_lease) }
      it { is_expected.not_to include(active_lease) }
      it { is_expected.not_to include(upcoming_lease) }
      it { is_expected.not_to include(expired_lease) }
      it { is_expected.not_to include(archived_lease) }
    end

    describe "archived" do
      subject { described_class.by_status("archived") }

      it { is_expected.to include(archived_lease) }
      it { is_expected.not_to include(active_lease) }
      it { is_expected.not_to include(upcoming_lease) }
      it { is_expected.not_to include(expired_lease) }
      it { is_expected.not_to include(terminated_lease) }
    end

    describe "unknown status" do
      it "returns no records" do
        expect(described_class.by_status("invalid")).to be_empty
      end
    end
  end

  describe ".not_archived" do
    let!(:regular_lease) { create(:lease) }
    let!(:archived_lease) do
      create(:lease, start_date: 6.months.ago.to_date, duration_months: 12,
                     terminated_on: 3.months.ago.to_date, archived_at: 1.month.ago)
    end

    it "includes non-archived leases" do
      expect(described_class.not_archived).to include(regular_lease)
    end

    it "excludes archived leases" do
      expect(described_class.not_archived).not_to include(archived_lease)
    end
  end

  describe "#archived?" do
    it "returns false when archived_at is nil" do
      expect(build(:lease, archived_at: nil)).not_to be_archived
    end

    it "returns true when archived_at is set" do
      lease = build(:lease, terminated_on: Date.new(2025, 2, 1), archived_at: 1.day.ago)
      expect(lease).to be_archived
    end
  end

  describe "archived_at validation" do
    it "is invalid when archived_at is set on a non-terminated lease" do
      lease = build(:lease, archived_at: 1.day.ago)
      lease.valid?
      expect(lease.errors[:archived_at]).to be_present
    end

    it "is valid when archived_at is set on a terminated lease" do
      lease = build(:lease, terminated_on: Date.new(2025, 2, 1), archived_at: 1.day.ago)
      expect(lease).to be_valid
    end

    it "is valid when archived_at is nil on any lease" do
      expect(build(:lease, archived_at: nil)).to be_valid
    end
  end

  describe "#recalculate_cached_balance!" do
    let(:lease) { create(:lease) }

    it "sets cached_balance to 0 when there are no invoices" do
      lease.recalculate_cached_balance!
      expect(lease.reload.cached_balance).to eq(0)
    end

    context "with finalized, sent, and partially_paid invoices" do
      before do
        create(:invoice, :with_balance, balance_amount: 500, lease: lease, status: :finalized)
        create(:invoice, :with_balance, balance_amount: 300, lease: lease, status: :sent)
        create(:invoice, :with_balance, balance_amount: 200, lease: lease, status: :partially_paid)
      end

      it "sums balances for all unsettled invoices" do
        lease.recalculate_cached_balance!
        expect(lease.reload.cached_balance).to eq(1000)
      end
    end

    context "with a paid invoice alongside a finalized one" do
      before do
        create(:invoice, :with_balance, balance_amount: 500, lease: lease, status: :finalized)
        create(:invoice, :with_balance, balance_amount: 0, lease: lease, status: :paid)
      end

      it "excludes paid invoices" do
        lease.recalculate_cached_balance!
        expect(lease.reload.cached_balance).to eq(500)
      end
    end

    context "with a cancelled invoice alongside a finalized one" do
      before do
        create(:invoice, :with_balance, balance_amount: 500, lease: lease, status: :finalized)
        create(:invoice, :with_balance, balance_amount: 400, lease: lease, status: :cancelled)
      end

      it "excludes cancelled invoices" do
        lease.recalculate_cached_balance!
        expect(lease.reload.cached_balance).to eq(500)
      end
    end

    context "with a credit note" do
      before do
        create(:invoice, :with_balance, balance_amount: 1000, lease: lease, status: :finalized)
        create(:invoice, :credit_note, :with_balance, balance_amount: -200, lease: lease, status: :finalized)
      end

      it "incorporates credit note balances (negative)" do
        lease.recalculate_cached_balance!
        expect(lease.reload.cached_balance).to eq(800)
      end
    end
  end

  describe "#overdue_balance" do
    let(:lease) { create(:lease) }

    it "returns 0 when there are no invoices" do
      expect(lease.overdue_balance).to eq(0)
    end

    it "sums only overdue invoice balances" do
      create(:invoice, :with_balance, balance_amount: 300, lease: lease, status: :finalized,
                                      due_date: 2.days.ago)
      create(:invoice, :with_balance, balance_amount: 200, lease: lease, status: :finalized,
                                      due_date: 10.days.from_now)
      expect(lease.overdue_balance).to eq(300)
    end

    it "returns 0 when an invoice is not yet due" do
      create(:invoice, :with_balance, balance_amount: 500, lease: lease, status: :finalized,
                                      due_date: 1.day.from_now)
      expect(lease.overdue_balance).to eq(0)
    end

    it "reflects the current date without requiring recalculation" do
      create(:invoice, :with_balance, balance_amount: 500, lease: lease, status: :finalized,
                                      due_date: 1.day.from_now)
      travel_to(2.days.from_now) do
        expect(lease.overdue_balance).to eq(500)
      end
    end
  end

  describe "#near_due_balance" do
    let(:lease) { create(:lease) }

    it "returns 0 when there are no invoices" do
      expect(lease.near_due_balance).to eq(0)
    end

    it "sums only near-due invoice balances" do
      create(:invoice, :with_balance, balance_amount: 400, lease: lease, status: :finalized,
                                      due_date: 3.days.from_now)
      create(:invoice, :with_balance, balance_amount: 100, lease: lease, status: :finalized,
                                      due_date: 20.days.from_now)
      expect(lease.near_due_balance).to eq(400)
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

  describe "default invoice template creation" do
    it { is_expected.to have_many(:invoice_templates).dependent(:destroy) }

    context "when creating a regular lease" do
      let(:lease) { create(:lease, tax_rate: 18, payment_due_in: 14.days) }
      let(:template) { lease.invoice_templates.first }

      it "creates the default template", :aggregate_failures do
        expect(lease.invoice_templates.count).to eq(1)
        expect(template).to have_attributes(name: "Rent", payment_due_in: 14.days, starts_on: nil, ends_on: nil)
        expect(template.line_items.map(&:amount_expression)).to eq(["rent", "rent * (prorata - 1)"])
        expect(template.line_items.map(&:tax_rate)).to all(eq(18))
      end
    end

    context "when the default template cannot be saved" do
      before do
        builder = instance_double(InvoiceTemplates::DefaultBuilder, call: InvoiceTemplate.new)
        allow(InvoiceTemplates::DefaultBuilder).to receive(:new).and_return(builder)
      end

      it "still creates the lease, without templates", :aggregate_failures do
        lease = create(:lease)
        expect(lease).to be_persisted
        expect(lease.invoice_templates).to be_empty
      end
    end

    context "when the lease is a renewal" do
      let(:old_lease) { create(:lease, start_date: Date.new(2024, 1, 1), duration_months: 12) }
      let(:renewal) { described_class.build_renewal(old_lease).tap(&:save!) }
      let(:maintenance) { renewal.invoice_templates.detect { |t| t.name == "Maintenance" } }

      before do
        create(:invoice_template, lease: old_lease, name: "Maintenance",
                                  payment_due_in: 5.days, starts_on: Date.new(2024, 3, 1))
      end

      it "copies the previous lease's templates instead of building the default", :aggregate_failures do
        expect(renewal.invoice_templates.map(&:name)).to contain_exactly("Rent", "Maintenance")
        expect(maintenance.payment_due_in).to eq(5.days)
        expect(maintenance.starts_on).to be_nil
        expect(maintenance.line_items.map(&:amount_expression)).to eq(["rent"])
      end
    end
  end
end
