# frozen_string_literal: true

require "rails_helper"

RSpec.describe BatchInvoiceGenerator do
  describe "#call" do
    subject(:generate_invoices) { described_class.new(date).call }

    let(:date) { Date.current }
    let!(:active_lease) { create(:lease, start_date: date - 1.month, duration_months: 12) }
    let!(:expired_lease) { create(:lease, start_date: date - 2.years, duration_months: 12) }
    let!(:future_lease) { create(:lease, start_date: date + 1.month, duration_months: 12) }

    it "creates invoices from the templates of active leases", :aggregate_failures do
      expect { generate_invoices }.to change(Invoice, :count).by(1)
      expect(Invoice.last).to have_attributes(lease: active_lease, date: date.beginning_of_month,
                                              status: "draft",
                                              invoice_template: active_lease.invoice_templates.first)
    end

    it "does not create invoices for leases whose window has passed" do
      generate_invoices
      expect(Invoice.where(lease: expired_lease).where.not(invoice_template_id: nil)).to be_empty
    end

    it "does not create invoices for leases starting in a future month" do
      generate_invoices
      expect(Invoice.where(lease: future_lease).where.not(invoice_template_id: nil)).to be_empty
    end

    context "when a lease starts later this month" do
      let!(:mid_month_lease) do
        create(:lease, start_date: date.end_of_month, duration_months: 12, rent_amount: 3100)
      end

      it "generates its first, pro-rated invoice in this month's run" do
        generate_invoices
        invoice = Invoice.where(lease: mid_month_lease).where.not(invoice_template_id: nil).first
        expect(invoice.line_items.map(&:category)).to include("rent", "discount")
      end
    end

    context "when a lease is archived (terminated with archived_at set)" do
      let!(:archived_lease) do
        create(:lease, start_date: date - 2.months, duration_months: 12,
                       terminated_on: date - 1.month, archived_at: date - 1.week)
      end

      it "does not create invoices for archived leases" do
        generate_invoices
        expect(Invoice.where(lease: archived_lease).where.not(invoice_template_id: nil)).to be_empty
      end
    end

    context "when a lease has multiple templates" do
      before do
        create(:invoice_template, lease: active_lease, name: "Maintenance").tap do |template|
          template.line_items.first.update!(name: "Fixed maintenance", amount_expression: "2500",
                                            category: "maintenance")
        end
      end

      it "creates one invoice per template" do
        expect { generate_invoices }.to change { Invoice.where(lease: active_lease).count }.by(2)
      end
    end

    context "when the template already generated an invoice for the month" do
      before do
        TemplateInvoiceGenerator.new(active_lease.invoice_templates.first, date).call.save!
      end

      it "does not create a duplicate invoice" do
        expect { generate_invoices }.not_to change(Invoice, :count)
      end
    end

    context "when only a security deposit invoice exists for the month" do
      before do
        invoice = create(:invoice, lease: active_lease, date: date.beginning_of_month)
        invoice.line_items.create!(name: "Security Deposit", amount: 2000, category: "security_deposit")
      end

      it "creates the rental invoice" do
        expect { generate_invoices }.to change(Invoice, :count).by(1)
      end
    end

    context "when a lease has no templates" do
      before { active_lease.invoice_templates.destroy_all }

      it "skips the lease silently" do
        expect { generate_invoices }.not_to change(Invoice, :count)
      end
    end

    context "when a template window excludes the current month" do
      before do
        active_lease.invoice_templates.first.update!(ends_on: date.beginning_of_month - 1.day)
      end

      it "does not generate an invoice" do
        expect { generate_invoices }.not_to change(Invoice, :count)
      end
    end

    context "when a template expression fails to evaluate" do
      before do
        # Valid at save time (known variables, parseable) but divides by zero.
        broken = create(:invoice_template, lease: active_lease, name: "Broken")
        broken.line_items.first.update!(amount_expression: "rent / (n - n)")
      end

      it "skips the broken template and still processes the rest" do
        expect { generate_invoices }.to change(Invoice, :count).by(1)
      end
    end
  end
end
