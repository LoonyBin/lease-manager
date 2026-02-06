# frozen_string_literal: true

require "rails_helper"

RSpec.describe SecurityDepositInvoicer do
  let(:owner) { create(:owner) }
  let(:property) { create(:property, owner: owner) }
  let(:tenant) { create(:tenant) }

  describe "Lease creation" do
    context "when start date is in the past" do
      subject(:invoice) { lease.invoices.last }

      let(:past_date) { 1.month.ago.to_date }
      let!(:lease) { create_lease(start_date: past_date) }

      it "creates a security deposit invoice" do
        expect(invoice).to be_present
      end

      it "sets legacy date on invoice" do
        expect(invoice.date).to eq(past_date)
      end

      it "sets correct invoice attributes" do
        aggregate_failures do
          expect(invoice.document_type).to eq("invoice")
          expect(invoice.total_amount).to eq(2000.0)
          expect(invoice.line_items.first.name).to eq("Security Deposit")
        end
      end
    end

    context "when start date is in the future" do
      subject(:invoice) { lease.invoices.last }

      let!(:lease) { create_lease(start_date: 1.month.from_now.to_date) }

      it "creates a security deposit invoice" do
        expect(invoice).to be_present
      end

      it "sets current date on invoice" do
        expect(invoice.date).to eq(Date.current)
      end

      it "sets correct invoice attributes" do
        aggregate_failures do
          expect(invoice.document_type).to eq("invoice")
          expect(invoice.total_amount).to eq(2000.0)
          expect(invoice.line_items.first.name).to eq("Security Deposit")
        end
      end
    end
  end

  describe "Lease termination" do
    subject(:refund) do
      lease.update!(terminated_on: Date.current + 1.day)
      lease.invoices.last
    end

    let!(:lease) do
      create(:lease, property: property, tenant: tenant, rent_amount: 1000, security_deposit_in_months: 2)
    end

    it "creates a refund credit note" do
      l = lease # Trigger creation
      expect { l.update!(terminated_on: Date.current + 1.day) }.to change(Invoice, :count).by(1)
    end

    it "sets correct refund attributes" do
      aggregate_failures do
        expect(refund.document_type).to eq("credit_note")
        expect(refund.total_amount).to eq(2000.0)
        expect(refund.line_items.first.name).to eq("Security Deposit Refund")
      end
    end
  end

  def create_lease(start_date:)
    create(:lease, property: property, tenant: tenant, start_date: start_date, rent_amount: 1000,
                   security_deposit_in_months: 2)
  end
end
