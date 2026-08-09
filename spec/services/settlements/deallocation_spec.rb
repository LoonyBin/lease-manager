# frozen_string_literal: true

require "rails_helper"

RSpec.describe Settlements::Deallocation do
  let(:lease) { create(:lease) }

  def finalized_invoice(amount:, date: Time.zone.today)
    invoice = create(:invoice, lease: lease, date: date, status: :draft)
    invoice.line_items.destroy_all
    create(:line_item, invoice: invoice, amount: amount.abs, tax_rate: nil)
    invoice.update!(status: :finalized)
    invoice.reload
  end

  describe ".deallocate" do
    context "with a partially_allocated payment" do
      let!(:invoice) { finalized_invoice(amount: 1000) }
      let!(:payment) { create(:payment, lease: lease, amount: 1500, status: :confirmed) }
      let(:result) { described_class.deallocate(payment) }

      it "clears the payment's footprint", :aggregate_failures do
        result
        expect(payment.reload.entries).to be_empty
        expect(payment.balance).to eq(0)
      end

      # Sweep 1 (recalculate_balances): remove_footprint zeroes the balance, so
      # without the +except:+ thread this would be recomputed to fully_allocated.
      it "retains the payment's input status" do
        result
        expect(payment.reload).to be_partially_allocated
      end

      it "frees the invoice and reconciles the lease", :aggregate_failures do
        result
        expect(invoice.reload.balance).to eq(1000)
        expect(invoice).to be_finalized
        expect(lease.reload.cached_balance).to eq(1000)
        expect(lease.entries.sum(:amount)).to eq(lease.cached_balance)
      end

      it "returns the removed footprint", :aggregate_failures do
        expect(result[:payment]).to eq(payment)
        expect(result[:counterparts]).to contain_exactly(invoice)
        expect(result[:entries_removed]).to eq(3)
        expect(result[:transactions_removed]).to eq(1)
      end

      it "reports the balance delta", :aggregate_failures do
        expect(result[:old_balance]).to eq(-500)
        expect(result[:new_balance]).to eq(1000)
      end

      it "removes both sides of every settlement" do
        txn_id = payment.entries.settlements.first.transaction_id
        result
        expect(Entry.where(transaction_id: txn_id)).to be_empty
      end

      it "is idempotent", :aggregate_failures do
        result
        expect { described_class.deallocate(payment) }.not_to raise_error
        expect(payment.reload.entries).to be_empty
      end
    end

    context "with a fully_allocated payment" do
      let!(:invoice) { finalized_invoice(amount: 1000) }
      let!(:payment) { create(:payment, lease: lease, amount: 1000, status: :confirmed) }

      before { described_class.deallocate(payment) }

      it "clears the footprint and frees the invoice", :aggregate_failures do
        expect(payment.reload.entries).to be_empty
        expect(payment.balance).to eq(0)
        expect(invoice.reload.balance).to eq(1000)
        expect(lease.reload.cached_balance).to eq(1000)
      end
    end

    context "when another credit can absorb the freed invoice" do
      # capo's full-re-inference example: de-allocating the first payment lets
      # the second one settle the now-freed invoice.
      let!(:invoice) { finalized_invoice(amount: 1000) }
      let!(:first_payment) { create(:payment, lease: lease, amount: 1000, status: :confirmed) }
      let!(:second_payment) { create(:payment, lease: lease, amount: 1000, status: :confirmed) }

      before { described_class.deallocate(first_payment) }

      it "re-settles the invoice from the surviving credit", :aggregate_failures do
        expect(invoice.reload).to be_paid
        expect(second_payment.reload).to be_fully_allocated
        expect(lease.reload.cached_balance).to eq(0)
      end
    end

    context "with a refund settled against a payment" do
      let!(:payment) { create(:payment, lease: lease, amount: 500, status: :confirmed) }
      let!(:refund) { create(:payment, :refund, lease: lease, amount: 200, status: :confirmed) }

      it "de-allocates without ArgumentError and makes the payment whole", :aggregate_failures do
        expect { described_class.deallocate(refund) }.not_to raise_error
        expect(refund.reload.entries).to be_empty
        expect(payment.reload.balance).to eq(-500)
      end

      it "recomputes cached_balance with nothing to cascade it" do
        lease.update_column(:cached_balance, 9999) # rubocop:disable Rails/SkipsModelValidations
        described_class.deallocate(refund)
        expect(lease.reload.cached_balance).to eq(0)
      end
    end

    context "when re-inference raises" do
      let(:payment) { create(:payment, lease: lease, amount: 1500, status: :confirmed) }

      before do
        finalized_invoice(amount: 1000)
        payment
        allow(described_class).to receive(:reinfer_lease).and_raise("boom")
      end

      it "rolls back the removed footprint", :aggregate_failures do
        expect { described_class.deallocate(payment) }.to raise_error("boom")
        expect(payment.reload.entries.count).to eq(2)
        expect(payment.balance).to eq(-500)
      end
    end

    describe "audit trail" do
      let(:payment) { create(:payment, lease: lease, amount: 1000, status: :confirmed) }

      before do
        finalized_invoice(amount: 1000)
        payment
      end

      def entry_destroys
        PaperTrail::Version.where(item_type: "Entry", event: "destroy").count
      end

      it "records a destroy version for every removed entry" do
        before_count = entry_destroys
        result = described_class.deallocate(payment)
        expect(entry_destroys - before_count).to eq(result[:entries_removed])
      end

      it "captures the destroyed entry in the version object", :aggregate_failures do
        described_class.deallocate(payment)
        object = JSON.parse(PaperTrail::Version.where(item_type: "Entry", event: "destroy").last.object)
        expect(object).to include("amount", "transaction_id")
      end
    end
  end

  describe ".reallocate" do
    context "with the payment on its original lease" do
      let!(:invoice) { finalized_invoice(amount: 1000) }
      let!(:payment) { create(:payment, lease: lease, amount: 1000, status: :confirmed) }

      before { described_class.deallocate(payment) }

      it "re-establishes and re-settles the payment", :aggregate_failures do
        described_class.reallocate(payment)
        expect(payment.reload).to be_fully_allocated
        expect(invoice.reload).to be_paid
      end
    end

    context "with a stranded initial entry" do
      let(:lease2) { create(:lease) }
      let!(:payment) { create(:payment, lease: lease, amount: 1000, status: :confirmed) }

      # Move the payment without callbacks so its initial entry stays on lease 1.
      before do
        payment.update_columns(lease_id: lease2.id) # rubocop:disable Rails/SkipsModelValidations
        payment.reload
      end

      it "re-homes the initial entry to the payment's lease" do
        described_class.reallocate(payment)
        expect(payment.reload.entries.initial.first.lease).to eq(lease2)
      end
    end

    context "when re-homed to another lease" do
      let!(:source_invoice) { finalized_invoice(amount: 1000) }
      let(:lease2) { create(:lease) }
      let!(:dest_invoice) { destination_invoice }
      let!(:payment) { create(:payment, lease: lease, amount: 1000, status: :confirmed) }

      def destination_invoice
        inv = create(:invoice, lease: lease2, date: Time.zone.today, status: :draft)
        create(:line_item, invoice: inv, amount: 1000, tax_rate: nil)
        inv.update!(status: :finalized)
        inv.reload
      end

      before do
        ActiveRecord::Base.transaction do
          described_class.deallocate(payment)
          payment.update!(lease: lease2)
          described_class.reallocate(payment)
        end
      end

      it "frees the source invoice and settles the destination", :aggregate_failures do
        expect(source_invoice.reload).to be_finalized
        expect(dest_invoice.reload).to be_paid
      end

      it "moves the balances with the payment", :aggregate_failures do
        expect(lease.reload.cached_balance).to eq(1000)
        expect(lease2.reload.cached_balance).to eq(0)
      end
    end
  end

  describe "#reinfer_lease exclusion routing" do
    # Sweep 3 (unsettled_debits) is only discriminable here: with no preceding
    # remove_footprint the refund keeps a non-zero balance, so the zero-balance
    # guard cannot mask a broken +except:+ thread. A broken thread would let the
    # payment settle against the refund, giving it a settlement entry.
    it "excludes the excepted instrument from the debit sweep" do
      create(:payment, lease: lease, amount: 200, status: :confirmed)
      refund = create(:payment, :refund, lease: lease, amount: 500, status: :confirmed)
      described_class.send(:reinfer_lease, lease, except: refund)
      expect(refund.reload.entries.settlements).to be_empty
    end
  end
end
