# frozen_string_literal: true

require "rails_helper"

RSpec.describe InvoiceTemplate do
  subject(:template) { build(:invoice_template) }

  describe "associations" do
    it { is_expected.to belong_to(:lease) }
    it { is_expected.to have_many(:line_items).dependent(:destroy) }
    it { is_expected.to have_many(:invoices).dependent(:nullify) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:payment_due_in) }

    it "rejects a negative payment_due_in" do
      template = build(:invoice_template, payment_due_in: -1.day)
      template.valid?
      expect(template.errors[:payment_due_in]).to include("must be non-negative")
    end

    it "rejects ends_on before starts_on" do
      template = build(:invoice_template, starts_on: Date.new(2025, 6, 1), ends_on: Date.new(2025, 5, 1))
      template.valid?
      expect(template.errors[:ends_on]).to include("must be on or after the start date")
    end

    it "requires at least one line item" do
      template = build(:invoice_template)
      template.line_items = []
      template.valid?
      expect(template.errors[:base]).to include("must have at least one line item")
    end

    it "rejects removing every line item on update" do
      template = create(:invoice_template)
      template.assign_attributes(line_items_attributes: [{ id: template.line_items.first.id, _destroy: "1" }])
      expect(template).not_to be_valid
    end
  end

  describe "#effective_starts_on / #effective_ends_on" do
    let(:lease) { create(:lease, start_date: Date.new(2025, 1, 1), duration_months: 12) }

    it "follows the lease dates when windows are nil", :aggregate_failures do
      template = create(:invoice_template, lease: lease)
      expect(template.effective_starts_on).to eq(Date.new(2025, 1, 1))
      expect(template.effective_ends_on).to eq(Date.new(2025, 12, 31))
    end

    it "uses explicit window dates when set", :aggregate_failures do
      template = create(:invoice_template, lease: lease,
                                           starts_on: Date.new(2025, 3, 1), ends_on: Date.new(2025, 6, 30))
      expect(template.effective_starts_on).to eq(Date.new(2025, 3, 1))
      expect(template.effective_ends_on).to eq(Date.new(2025, 6, 30))
    end

    it "caps an explicit end date at the lease end date" do
      template = create(:invoice_template, lease: lease, ends_on: Date.new(2027, 1, 1))
      expect(template.effective_ends_on).to eq(Date.new(2025, 12, 31))
    end

    it "shrinks with the lease when it is terminated" do
      template = create(:invoice_template, lease: lease)
      lease.update!(terminated_on: Date.new(2025, 5, 10))
      expect(template.effective_ends_on).to eq(Date.new(2025, 5, 10))
    end
  end

  describe "#generates_for?" do
    let(:lease) { create(:lease, start_date: Date.new(2025, 1, 15), duration_months: 12) }
    let(:template) { create(:invoice_template, lease: lease) }

    it "is true for the partial first month" do
      expect(template.generates_for?(Date.new(2025, 1, 1))).to be true
    end

    it "is true for a mid-lease month" do
      expect(template.generates_for?(Date.new(2025, 6, 20))).to be true
    end

    it "is true for the final month" do
      expect(template.generates_for?(Date.new(2025, 12, 31))).to be true
    end

    it "is false before the lease starts" do
      expect(template.generates_for?(Date.new(2024, 12, 31))).to be false
    end

    it "is false after the lease ends" do
      expect(template.generates_for?(Date.new(2026, 1, 1))).to be false
    end

    it "respects an explicit window" do
      scoped = create(:invoice_template, lease: lease,
                                         starts_on: Date.new(2025, 3, 1), ends_on: Date.new(2025, 4, 30))
      results = (2..5).index_with { |month| scoped.generates_for?(Date.new(2025, month, 15)) }
      expect(results).to eq(2 => false, 3 => true, 4 => true, 5 => false)
    end
  end

  describe ".for_active_leases" do
    let!(:archived_lease) do
      create(:lease, start_date: Date.new(2024, 1, 1), duration_months: 12,
                     terminated_on: Date.new(2024, 6, 1), archived_at: Time.current)
    end
    let!(:active_lease) { create(:lease) }

    it "excludes templates of archived leases", :aggregate_failures do
      expect(described_class.for_active_leases).to include(*active_lease.invoice_templates)
      expect(described_class.for_active_leases).not_to include(*archived_lease.invoice_templates)
    end
  end
end
