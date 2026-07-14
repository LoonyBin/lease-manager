# frozen_string_literal: true

require "rails_helper"

RSpec.describe MissingInvoiceDetector do
  describe "#call" do
    subject(:result) { described_class.new.call }

    let(:today) { Date.current }

    context "when a lease has no generated invoices" do
      let!(:lease) { create(:lease, start_date: today - 2.months, duration_months: 12) }

      it "returns missing invoice structs for each expected month" do
        expect(result.size).to eq(3) # 2 months ago, 1 month ago, current month
      end

      it "includes the lease, template, tenant, and property", :aggregate_failures do
        first = result.first
        expect(first.lease).to eq(lease)
        expect(first.template).to eq(lease.invoice_templates.first)
        expect(first.tenant).to eq(lease.tenant)
        expect(first.property).to eq(lease.property)
      end

      it "computes the expected amount from the template including tax" do
        # Full months: rent 1000 at 18% tax
        expect(result.last.expected_amount).to eq(1180)
      end

      it "sorts results by date ascending" do
        dates = result.map(&:date)
        expect(dates).to eq(dates.sort)
      end
    end

    context "when a template generated some invoices" do
      let!(:lease) { create(:lease, start_date: today - 2.months, duration_months: 12) }

      before do
        TemplateInvoiceGenerator.new(lease.invoice_templates.first, today - 2.months).call.save!
      end

      it "excludes months that already have an invoice from the template" do
        expect(result.map(&:date)).not_to include((today - 2.months).beginning_of_month)
      end

      it "includes months without an invoice from the template" do
        expect(result.map(&:date)).to include(today.beginning_of_month)
      end
    end

    context "when an invoice exists without a template link" do
      let!(:lease) { create(:lease, start_date: today.beginning_of_month, duration_months: 12) }

      before do
        invoice = create(:invoice, lease: lease, date: today.beginning_of_month)
        invoice.line_items.create!(name: "Security Deposit", amount: 2000, category: "security_deposit")
      end

      it "still flags the month as missing" do
        expect(result.map(&:date)).to include(today.beginning_of_month)
      end
    end

    context "when rent was billed manually for the month (no template link)" do
      let!(:lease) { create(:lease, start_date: today.beginning_of_month, duration_months: 12) }

      before do
        invoice = create(:invoice, lease: lease, date: today.beginning_of_month)
        invoice.line_items.create!(name: "Rent (manual)", amount: 1000, category: "rent")
      end

      it "treats the month as covered" do
        expect(result.map(&:date)).not_to include(today.beginning_of_month)
      end
    end

    context "when a lease has multiple templates" do
      let!(:lease) { create(:lease, start_date: today.beginning_of_month, duration_months: 12) }
      let!(:extra_template) { create(:invoice_template, lease: lease, name: "Maintenance") }

      it "reports each template separately" do
        expect(result.map(&:template)).to contain_exactly(lease.invoice_templates.first, extra_template)
      end
    end

    context "when a template expression fails to evaluate" do
      let!(:lease) { create(:lease, start_date: today.beginning_of_month, duration_months: 12) }

      before do
        # Valid at save time (known variables, parseable) but divides by zero.
        lease.invoice_templates.first.line_items.first.update!(amount_expression: "rent / (n - n)")
      end

      it "still reports the month, without an expected amount", :aggregate_failures do
        expect(result.map(&:date)).to include(today.beginning_of_month)
        expect(result.first.expected_amount).to be_nil
      end
    end

    context "when a template window excludes past months" do
      let!(:lease) { create(:lease, start_date: today - 2.months, duration_months: 12) }

      before do
        lease.invoice_templates.first.update!(starts_on: today.beginning_of_month)
      end

      it "only expects months inside the window" do
        expect(result.map(&:date)).to eq([today.beginning_of_month])
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
        TemplateInvoiceGenerator.new(lease.invoice_templates.first, today).call.save!
      end

      it "returns an empty array" do
        expect(result).to be_empty
      end
    end
  end

  describe "#leases_without_templates" do
    subject(:detector) { described_class.new }

    it "lists leases whose templates were all deleted" do
      lease = create(:lease)
      lease.invoice_templates.destroy_all
      expect(detector.leases_without_templates).to contain_exactly(lease)
    end

    it "does not list leases with templates" do
      create(:lease)
      expect(detector.leases_without_templates).to be_empty
    end
  end
end
