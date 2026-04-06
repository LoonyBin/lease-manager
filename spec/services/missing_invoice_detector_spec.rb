# frozen_string_literal: true

require "rails_helper"

RSpec.describe MissingInvoiceDetector do
  describe "#call" do
    subject(:result) { described_class.new.call }

    let(:today) { Date.current }

    context "when a lease has no invoices" do
      let!(:lease) { create(:lease, start_date: today - 2.months, duration_months: 12) }

      it "returns missing invoice structs for each expected month" do
        expect(result.size).to eq(3) # 2 months ago, 1 month ago, current month
      end

      it "includes the correct lease, tenant, and property", :aggregate_failures do
        first = result.first
        expect(first.lease).to eq(lease)
        expect(first.tenant).to eq(lease.tenant)
        expect(first.property).to eq(lease.property)
      end

      it "sorts results by date ascending" do
        dates = result.map(&:date)
        expect(dates).to eq(dates.sort)
      end
    end

    context "when a lease has some invoices" do
      let!(:lease) { create(:lease, start_date: today - 2.months, duration_months: 12) }

      before do
        invoice = create(:invoice, lease: lease, date: (today - 2.months).beginning_of_month)
        invoice.line_items.create!(name: "Rent", amount: 1000, category: "rent")
      end

      it "excludes months that already have a rental invoice" do
        dates = result.map(&:date)
        expect(dates).not_to include((today - 2.months).beginning_of_month)
      end

      it "includes months without a rental invoice" do
        dates = result.map(&:date)
        expect(dates).to include(today.beginning_of_month)
      end
    end

    context "when a security deposit invoice exists for a month" do
      let!(:lease) { create(:lease, start_date: today.beginning_of_month, duration_months: 12) }

      before do
        invoice = create(:invoice, lease: lease, date: today.beginning_of_month)
        invoice.line_items.create!(name: "Security Deposit", amount: 2000, category: "security_deposit")
      end

      it "still flags the month as missing a rental invoice" do
        expect(result.map(&:date)).to include(today.beginning_of_month)
      end
    end

    context "when a lease is upcoming" do
      let!(:upcoming_lease) { create(:lease, start_date: today + 1.month, duration_months: 12) }

      it "excludes upcoming leases" do
        expect(result.map(&:lease)).not_to include(upcoming_lease)
      end
    end

    context "when a lease is archived" do
      let!(:archived_lease) do
        create(:lease, start_date: today - 6.months, duration_months: 12,
                       terminated_on: today - 2.months, archived_at: today - 1.month)
      end

      it "excludes archived leases" do
        expect(result.map(&:lease)).not_to include(archived_lease)
      end
    end

    context "when there are no missing invoices" do
      let!(:lease) { create(:lease, start_date: today.beginning_of_month, duration_months: 12) }

      before do
        invoice = create(:invoice, lease: lease, date: today.beginning_of_month)
        invoice.line_items.create!(name: "Rent", amount: 1000, category: "rent")
      end

      it "returns an empty array" do
        expect(result).to be_empty
      end
    end
  end
end
