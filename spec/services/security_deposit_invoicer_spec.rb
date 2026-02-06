# frozen_string_literal: true

require "rails_helper"

RSpec.describe SecurityDepositInvoicer do
  describe "#call" do
    context "when handling invoice dates" do
      it "uses today's date if lease starts in the future" do
        create(:lease, start_date: 1.month.from_now)
        expect(Invoice.last.date).to eq(Date.current)
      end

      it "uses lease start date if lease started in the past" do
        past_date = 1.month.ago.to_date
        create(:lease, start_date: past_date)
        expect(Invoice.last.date).to eq(past_date)
      end
    end

    context "when lease is new (not a renewal)" do
      subject(:invoice) do
        create_lease
        Invoice.last
      end

      let(:create_lease) do
        create(:lease, rent_amount: 1000, security_deposit_in_months: 2, start_date: 1.month.ago)
      end

      it "creates a security deposit invoice" do
        expect { create_lease }.to change(Invoice, :count).by(1)
      end

      it "sets the correct invoice attributes" do
        aggregate_failures do
          expect(invoice.document_type).to eq("invoice")
          expect(invoice.total_amount).to eq(2000.0)
          expect(invoice.line_items.first.name).to eq("Security Deposit")
        end
      end
    end

    context "when renewal has higher deposit" do
      subject(:invoice) do
        create_renewal
        Invoice.last
      end

      let!(:old_lease) do
        create(:lease, rent_amount: 1000, security_deposit_in_months: 2,
                       terminated_on: Date.yesterday, start_date: 1.year.ago)
      end

      let(:create_renewal) do
        create(:lease, property: old_lease.property, tenant: old_lease.tenant,
                       rent_amount: 1200, security_deposit_in_months: 2,
                       renewed_from: old_lease, start_date: Time.zone.today)
      end

      it "creates a difference invoice" do
        expect { create_renewal }.to change(Invoice, :count).by(1)
      end

      it "sets correct attributes for difference invoice" do
        aggregate_failures do
          expect(invoice.document_type).to eq("invoice")
          expect(invoice.total_amount).to eq(400.0)
          expect(invoice.line_items.first.name).to eq("Security Deposit Top-up")
        end
      end
    end

    context "when renewal has lower deposit" do
      subject(:invoice) do
        create_renewal
        Invoice.last
      end

      let!(:old_lease) do
        create(:lease, rent_amount: 1000, security_deposit_in_months: 2,
                       terminated_on: Date.yesterday, start_date: 1.year.ago)
      end

      let(:create_renewal) do
        create(:lease, property: old_lease.property, tenant: old_lease.tenant,
                       rent_amount: 800, security_deposit_in_months: 2,
                       renewed_from: old_lease, start_date: Time.zone.today)
      end

      it "creates a refund credit note" do
        expect { create_renewal }.to change(Invoice, :count).by(1)
      end

      it "sets correct attributes for refund credit note" do
        aggregate_failures do
          expect(invoice.document_type).to eq("credit_note")
          expect(invoice.total_amount).to eq(400.0)
          expect(invoice.line_items.first.name).to eq("Security Deposit Refund/Adjustment")
        end
      end
    end

    context "when renewal has same deposit" do
      let!(:old_lease) do
        create(:lease, rent_amount: 1000, security_deposit_in_months: 2,
                       terminated_on: Date.yesterday, start_date: 1.year.ago)
      end

      it "does nothing" do
        expect do
          create(:lease, property: old_lease.property, tenant: old_lease.tenant,
                         rent_amount: 1000, security_deposit_in_months: 2,
                         renewed_from: old_lease, start_date: Time.zone.today)
        end.not_to change(Invoice, :count)
      end
    end

    context "when lease is terminated" do
      subject(:invoice) do
        lease.update!(terminated_on: Time.zone.today)
        Invoice.last
      end

      let!(:lease) { create(:lease, rent_amount: 1000, security_deposit_in_months: 2, start_date: 1.month.ago) }

      it "creates a full refund credit note if not renewed" do
        expect { lease.update!(terminated_on: Time.zone.today) }
          .to change(Invoice, :count).by(1)
      end

      it "sets correct attributes for termination refund" do
        aggregate_failures do
          expect(invoice.document_type).to eq("credit_note")
          expect(invoice.total_amount).to eq(2000.0)
          expect(invoice.line_items.first.name).to eq("Security Deposit Refund")
        end
      end

      it "uses terminated_on as the credit note date" do
        termination_date = 1.week.from_now.to_date
        lease.update!(terminated_on: termination_date)

        expect(Invoice.last.date).to eq(termination_date)
      end

      it "does nothing if it was renewed" do
        create(:lease, renewed_from: lease, start_date: Time.zone.today + 1.day)

        expect { lease.update!(terminated_on: Time.zone.today) }
          .not_to change(Invoice, :count)
      end
    end

    context "when a renewal lease is terminated" do
      subject(:invoice) do
        renewal_lease.update!(terminated_on: Time.zone.today + 1.day)
        Invoice.last
      end

      let(:old_lease) do
        create(:lease, rent_amount: 1000, security_deposit_in_months: 2,
                       terminated_on: Date.yesterday, start_date: 1.year.ago)
      end
      let!(:renewal_lease) do
        create(:lease, property: old_lease.property, tenant: old_lease.tenant,
                       rent_amount: 1200, security_deposit_in_months: 2,
                       renewed_from: old_lease, start_date: Time.zone.today)
      end

      it "creates a full refund credit note" do
        expect { renewal_lease.update!(terminated_on: Time.zone.today + 1.day) }
          .to change(Invoice, :count).by(1)
      end

      it "sets correct attributes for renewal termination" do
        aggregate_failures do
          expect(invoice.document_type).to eq("credit_note")
          expect(invoice.total_amount).to eq(2400.0)
          expect(invoice.line_items.first.name).to eq("Security Deposit Refund")
        end
      end
    end
  end
end
