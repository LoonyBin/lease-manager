# frozen_string_literal: true

require "rails_helper"

RSpec.describe Payments::Correction do
  # A finalized, single-line, untaxed invoice on +on_lease+. Mirrors the helper
  # in spec/services/settlements/deallocation_spec.rb.
  def finalized_invoice(on_lease, amount:, date: Date.new(2025, 6, 1))
    invoice = create(:invoice, lease: on_lease, date: date, status: :draft)
    invoice.line_items.destroy_all
    create(:line_item, invoice: invoice, amount: amount, tax_rate: nil)
    invoice.update!(status: :finalized)
    invoice.reload
  end

  def codes_for(payment, attrs)
    described_class.call(payment, attrs).warnings.pluck(:code)
  end

  describe "editing amount on an allocated payment" do
    let(:lease) { create(:lease) }
    let!(:invoice) { finalized_invoice(lease, amount: 1000) }
    let(:payment) do
      create(:payment, lease: lease, amount: 1500, date: Date.new(2025, 6, 15), status: :confirmed)
    end
    let(:correction) { described_class.call(payment, { amount: 800 }) }

    before { correction }

    it "fully allocates the reduced payment" do
      expect(payment.reload).to be_fully_allocated
    end

    it "leaves the invoice partly outstanding" do
      expect(invoice.reload.balance).to eq(200)
    end

    it "re-infers the lease cached_balance" do
      expect(lease.reload.cached_balance).to eq(200)
    end

    it "raises no warnings for an in-term same-lease edit" do
      expect(correction.warnings).to be_empty
    end
  end

  describe "re-assigning to another lease" do
    let(:source) { create(:lease) }
    let!(:source_invoice) { finalized_invoice(source, amount: 1000) }

    def move_to(payment, destination)
      described_class.call(payment, { lease_id: destination.id })
    end

    context "with a same-tenant destination" do
      let(:payment) { create(:payment, lease: source, amount: 1000, date: Date.new(2025, 6, 15), status: :confirmed) }
      let(:destination) { create(:lease, tenant: source.tenant) }
      let!(:dest_invoice) { finalized_invoice(destination, amount: 1000) }

      it "re-homes the payment" do
        move_to(payment, destination)
        expect(payment.reload.lease).to eq(destination)
      end

      it "settles the destination and frees the source", :aggregate_failures do
        move_to(payment, destination)
        expect(dest_invoice.reload.balance).to eq(0)
        expect(source_invoice.reload.balance).to eq(1000)
      end

      it "moves the cached balances", :aggregate_failures do
        move_to(payment, destination)
        expect(source.reload.cached_balance).to eq(1000)
        expect(destination.reload.cached_balance).to eq(0)
      end

      it "does not warn about a different tenant" do
        expect(move_to(payment, destination).warnings.pluck(:code)).not_to include("different_tenant")
      end
    end

    context "with a different-tenant destination" do
      let(:payment) { create(:payment, lease: source, amount: 1000, date: Date.new(2025, 6, 15), status: :confirmed) }
      let(:destination) { create(:lease) }
      let!(:dest_invoice) { finalized_invoice(destination, amount: 1000) }

      it "moves the money across tenants", :aggregate_failures do
        move_to(payment, destination)
        expect(source_invoice.reload.balance).to eq(1000)
        expect(dest_invoice.reload.balance).to eq(0)
      end

      it "warns about the different tenant but still allows it" do
        expect(move_to(payment, destination).warnings.pluck(:code)).to include("different_tenant")
      end
    end

    context "with a partially_allocated payment (amount exceeds the source invoice)" do
      let(:payment) { create(:payment, lease: source, amount: 1500, date: Date.new(2025, 6, 15), status: :confirmed) }
      let(:destination) { create(:lease, tenant: source.tenant) }
      let!(:dest_invoice) { finalized_invoice(destination, amount: 2000) }

      it "fully absorbs into the larger destination invoice" do
        move_to(payment, destination)
        expect(payment.reload).to be_fully_allocated
      end

      it "leaves the destination invoice partly outstanding" do
        move_to(payment, destination)
        expect(dest_invoice.reload.balance).to eq(500)
      end
    end

    context "with a fully_allocated payment (amount equals the source invoice)" do
      let(:payment) { create(:payment, lease: source, amount: 1000, date: Date.new(2025, 6, 15), status: :confirmed) }
      let(:destination) { create(:lease, tenant: source.tenant) }
      let!(:dest_invoice) { finalized_invoice(destination, amount: 1000) }

      it "leaves the destination invoice paid" do
        move_to(payment, destination)
        expect(dest_invoice.reload).to be_paid
      end

      it "leaves the source invoice open" do
        move_to(payment, destination)
        expect(source_invoice.reload.balance).to eq(1000)
      end
    end
  end

  # Discriminator: a +date+ correction that moves a payment *earlier* must be
  # honoured by FULL chronological re-inference, not create-time replay. Here a
  # later credit has already absorbed the only invoice; pulling the target
  # payment ahead of it must hand the invoice to the target. Incremental
  # +reallocate+ (deallocate-excluding-target, re-settle the rest, then settle
  # the target against the leftovers) would leave the later credit on the invoice
  # and the target unallocated — so this goes red the moment the date branch
  # stops routing through +reinfer_lease+.
  describe "correcting a payment's date earlier" do
    let(:lease) { create(:lease) }
    let!(:invoice) { finalized_invoice(lease, amount: 1000, date: Date.new(2025, 1, 15)) }
    let(:later_credit) do
      create(:payment, lease: lease, amount: 1000, date: Date.new(2025, 6, 15), status: :confirmed)
    end
    let(:target) do
      create(:payment, lease: lease, amount: 1000, date: Date.new(2025, 11, 15), status: :confirmed)
    end

    before do
      later_credit
      target
      described_class.call(target, { date: Date.new(2025, 2, 15) })
    end

    it "hands the invoice to the now-earlier payment" do
      expect(target.reload).to be_fully_allocated
    end

    it "settles the invoice against the target" do
      expect(invoice.reload).to be_paid
    end

    it "leaves the once-earlier credit unallocated", :aggregate_failures do
      expect(later_credit.reload).not_to be_fully_allocated
      expect(later_credit.balance).to eq(-1000)
    end
  end

  describe "warnings" do
    let(:tenant) { create(:tenant) }
    let(:source) { create(:lease, tenant: tenant) }
    let(:payment) do
      create(:payment, lease: source, amount: 1000, date: Date.new(2025, 6, 15), status: :confirmed)
    end

    it "flags a payment date pushed outside the destination term" do
      # source term is 2025; pushing the date into 2026 leaves it after the end.
      expect(codes_for(payment, { date: Date.new(2026, 6, 15) })).to include("date_outside_term")
    end

    it "does not flag a date that stays inside the term" do
      expect(codes_for(payment, { date: Date.new(2025, 8, 15) })).not_to include("date_outside_term")
    end

    it "flags a terminated destination lease" do
      destination = create(:lease, tenant: tenant, terminated_on: Date.new(2025, 2, 1))
      expect(codes_for(payment, { lease_id: destination.id })).to include("destination_inactive")
    end

    context "with a source invoice the payment was covering" do
      let!(:source_invoice) { finalized_invoice(source, amount: 1000) }
      let(:destination) { create(:lease, tenant: tenant) }

      it "flags the source left newly outstanding", :aggregate_failures do
        expect(codes_for(payment, { lease_id: destination.id })).to include("source_newly_outstanding")
        expect(source_invoice.reload.balance).to eq(1000)
      end
    end

    it "does not flag a source that owed nothing" do
      # No source invoice: the payment carries live credit but the lease owes
      # nothing, so removing it cannot newly-outstand the source.
      destination = create(:lease, tenant: tenant)
      expect(codes_for(payment, { lease_id: destination.id })).not_to include("source_newly_outstanding")
    end
  end

  describe "atomicity" do
    let(:lease) { create(:lease) }
    let!(:invoice) { finalized_invoice(lease, amount: 1000) }
    let!(:payment) do
      create(:payment, lease: lease, amount: 1500, date: Date.new(2025, 6, 15), status: :confirmed)
    end

    it "rolls the payment back when re-inference raises", :aggregate_failures do
      allow(SettlementService).to receive(:reallocate).and_raise("boom")
      expect { described_class.call(payment, { amount: 800 }) }.to raise_error("boom")
      expect(payment.reload.amount).to eq(1500)
      expect(payment.balance).to eq(-500)
      expect(payment).to be_partially_allocated
    end

    it "rolls the ledger back when re-inference raises", :aggregate_failures do
      allow(SettlementService).to receive(:reallocate).and_raise("boom")
      expect { described_class.call(payment, { amount: 800 }) }.to raise_error("boom")
      expect(invoice.reload.balance).to eq(0)
      expect(lease.reload.cached_balance).to eq(0)
    end
  end

  describe "payments with no live footprint take the metadata path" do
    let(:lease) { create(:lease) }
    let(:other_lease) { create(:lease) }
    let(:draft) { create(:payment, lease: lease, amount: 1000, date: Date.new(2025, 6, 15), status: :draft) }
    let(:rejected) do
      finalized_invoice(lease, amount: 1000)
      create(:payment, lease: lease, amount: 1000, date: Date.new(2025, 6, 15), status: :confirmed)
        .tap { |p| p.update!(status: :rejected) }
    end

    it "edits a draft without creating a ledger footprint", :aggregate_failures do
      described_class.call(draft, { amount: 250 })
      expect(draft.reload.amount).to eq(250)
      expect(draft).to be_draft
      expect(draft.entries).to be_empty
    end

    it "re-homes a rejected payment without hitting reallocate's guard", :aggregate_failures do
      expect { described_class.call(rejected, { lease_id: other_lease.id }) }.not_to raise_error
      expect(rejected.reload.lease).to eq(other_lease)
      expect(rejected).to be_rejected
      expect(rejected.entries).to be_empty
    end
  end
end
