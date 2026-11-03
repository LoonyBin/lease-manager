# frozen_string_literal: true

require "rails_helper"

RSpec.describe Payment do
  describe "associations" do
    it { is_expected.to belong_to(:lease) }
    it { is_expected.to have_many(:entries).dependent(:destroy) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:amount) }
    it { is_expected.to validate_numericality_of(:amount).is_greater_than(0) }
    it { is_expected.to validate_presence_of(:date) }
    it { is_expected.to validate_presence_of(:mode) }
  end

  describe "enums" do
    it do
      expected_modes = {
        rtgs: 0, neft: 1, imps: 2, upi: 3, cheque: 4,
        cash: 5, demand_draft: 6, tax_deducted_at_source: 7
      }
      is_expected.to define_enum_for(:mode).with_values(expected_modes)
    end

    it { is_expected.to define_enum_for(:payment_type).with_values(payment: 0, refund: 1) }

    it do
      is_expected.to define_enum_for(:status)
        .with_values(draft: 0, confirmed: 1, rejected: 2, partially_allocated: 3, fully_allocated: 4)
        .with_default(:confirmed)
    end
  end

  describe "attachments" do
    it { is_expected.to have_one_attached(:attachment) }
  end

  describe "callbacks for confirmed payments" do
    let(:lease) { create(:lease) }

    it "creates an initial entry when created" do
      payment = create(:payment, lease: lease, amount: 100, status: :confirmed)
      expect(payment.entries.initial.count).to eq(1)
    end

    it "sets balance from entry amount" do
      payment = create(:payment, lease: lease, amount: 100, status: :confirmed)
      expect(payment.balance).to eq(-100)
    end

    it "auto-settles after creation" do
      allow(SettlementService).to receive(:auto_settle)
      create(:payment, lease: lease, amount: 100, status: :confirmed)
      expect(SettlementService).to have_received(:auto_settle)
    end

    it "updates status to partially_allocated after creation with no invoices" do
      payment = create(:payment, lease: lease, amount: 100, status: :confirmed)
      expect(payment.reload).to be_partially_allocated
    end
  end

  describe "callbacks for draft payments" do
    let(:lease) { create(:lease) }

    it "does not create an initial entry" do
      payment = create(:payment, lease: lease, amount: 100, status: :draft)
      expect(payment.entries.count).to eq(0)
    end

    it "does not set balance" do
      payment = create(:payment, lease: lease, amount: 100, status: :draft)
      expect(payment.balance).to eq(0)
    end

    it "does not auto-settle" do
      allow(SettlementService).to receive(:auto_settle)
      create(:payment, lease: lease, amount: 100, status: :draft)
      expect(SettlementService).not_to have_received(:auto_settle)
    end
  end

  describe "status change from draft to confirmed" do
    let(:lease) { create(:lease) }
    let(:payment) { create(:payment, lease: lease, amount: 100, status: :draft) }

    it "creates an initial entry when confirmed" do
      payment.update!(status: :confirmed)
      expect(payment.entries.initial.count).to eq(1)
    end

    it "sets the balance when confirmed" do
      payment.update!(status: :confirmed)
      expect(payment.balance).to eq(-100)
    end

    it "triggers auto-settlement when confirmed" do
      allow(SettlementService).to receive(:auto_settle)
      payment.update!(status: :confirmed)
      expect(SettlementService).to have_received(:auto_settle).with(payment)
    end

    it "does not create duplicate entries if already allocated" do
      allocated_payment = create(:payment, lease: lease, amount: 50, status: :confirmed)
      initial_entry_count = allocated_payment.entries.count

      allocated_payment.update!(status: :partially_allocated)

      expect(allocated_payment.entries.count).to eq(initial_entry_count)
    end
  end

  describe "#update_status_from_balance!" do
    let(:lease) { create(:lease) }

    it "sets partially_allocated when balance remains" do
      payment = create(:payment, lease: lease, amount: 100, status: :confirmed)
      expect(payment.reload).to be_partially_allocated
    end

    it "sets fully_allocated when balance is zero" do
      invoice = create(:invoice, lease: lease)
      create(:line_item, invoice: invoice, amount: 100)
      invoice.update!(status: :finalized)
      payment = create(:payment, lease: lease, amount: 100, status: :confirmed)
      expect(payment.reload).to be_fully_allocated
    end

    it "does not change status when recalculating a rejected payment" do
      payment = create(:payment, lease: lease, amount: 100, status: :confirmed)
      payment.update!(status: :rejected)
      payment.recalculate_balance!
      expect(payment).to be_rejected
    end
  end

  describe "de-allocation on rejection" do
    let(:lease) { create(:lease) }

    def finalized_invoice(amount:)
      invoice = create(:invoice, lease: lease, date: Time.zone.today, status: :draft)
      create(:line_item, invoice: invoice, amount: amount, tax_rate: nil)
      invoice.update!(status: :finalized)
      invoice.reload
    end

    context "when a partially_allocated payment is rejected" do
      let!(:invoice) { finalized_invoice(amount: 1000) }
      let!(:payment) { create(:payment, lease: lease, amount: 1500, status: :confirmed) }

      before { payment.update!(status: :rejected) }

      it "removes all of the payment's entries" do
        expect(payment.reload.entries).to be_empty
      end

      it "zeroes the balance and keeps it rejected", :aggregate_failures do
        payment.reload
        expect(payment.balance).to eq(0)
        expect(payment).to be_rejected
      end

      it "reverts the invoice to finalized with its full balance", :aggregate_failures do
        invoice.reload
        expect(invoice.balance).to eq(1000)
        expect(invoice).to be_finalized
      end

      it "restores the lease balance so entries and cache agree", :aggregate_failures do
        lease.reload
        expect(lease.cached_balance).to eq(1000)
        expect(lease.entries.sum(:amount)).to eq(lease.cached_balance)
      end
    end

    context "when a fully_allocated payment is rejected" do
      let!(:invoice) { finalized_invoice(amount: 1000) }
      let!(:payment) { create(:payment, lease: lease, amount: 1000, status: :confirmed) }

      before { payment.update!(status: :rejected) }

      it "removes the entries and zeroes the balance", :aggregate_failures do
        payment.reload
        expect(payment.entries).to be_empty
        expect(payment.balance).to eq(0)
      end

      it "frees the invoice and restores the lease balance", :aggregate_failures do
        expect(invoice.reload.balance).to eq(1000)
        expect(invoice.reload).to be_finalized
        expect(lease.reload.cached_balance).to eq(1000)
        expect(lease.entries.sum(:amount)).to eq(lease.cached_balance)
      end
    end

    context "when re-inference raises mid-transition" do
      let(:payment) { create(:payment, lease: lease, amount: 1500, status: :confirmed) }

      before do
        finalized_invoice(amount: 1000)
        payment
        allow(Settlements::Deallocation).to receive(:reinfer_lease).and_raise("boom")
      end

      it "rolls back completely, leaving the payment allocated", :aggregate_failures do
        expect { payment.update!(status: :rejected) }.to raise_error("boom")
        payment.reload
        expect(payment).to be_partially_allocated
        expect(payment.balance).to eq(-500)
        expect(payment.entries.count).to eq(2)
      end
    end

    context "when a rejected payment is reinstated to confirmed" do
      let!(:invoice) { finalized_invoice(amount: 1000) }
      let!(:payment) { create(:payment, lease: lease, amount: 1500, status: :confirmed) }

      before do
        payment.update!(status: :rejected)
        payment.update!(status: :confirmed)
      end

      it "re-allocates the payment", :aggregate_failures do
        payment.reload
        expect(payment).to be_partially_allocated
        expect(payment.balance).to eq(-500)
        expect(payment.entries.initial.count).to eq(1)
      end

      it "re-settles the invoice", :aggregate_failures do
        expect(invoice.reload.balance).to eq(0)
        expect(invoice.reload).to be_paid
      end
    end

    it "does not de-allocate a draft payment that is rejected" do
      allow(SettlementService).to receive(:deallocate)
      payment = create(:payment, lease: lease, amount: 100, status: :draft)
      payment.update!(status: :rejected)
      expect(SettlementService).not_to have_received(:deallocate)
    end

    it "does not de-allocate a payment created already rejected" do
      allow(SettlementService).to receive(:deallocate)
      create(:payment, lease: lease, amount: 100, status: :rejected)
      expect(SettlementService).not_to have_received(:deallocate)
    end
  end

  describe "#signed_amount" do
    it "returns negative amount for payments (credit)" do
      payment = build(:payment, amount: 100, payment_type: :payment)
      expect(payment.signed_amount).to eq(-100)
    end

    it "returns positive amount for refunds (debit)" do
      payment = build(:payment, amount: 100, payment_type: :refund)
      expect(payment.signed_amount).to eq(100)
    end
  end

  describe "#credit? and #debit?" do
    it "payment is credit", :aggregate_failures do
      payment = build(:payment, payment_type: :payment)
      expect(payment.credit?).to be true
      expect(payment.debit?).to be false
    end

    it "refund is debit", :aggregate_failures do
      payment = build(:payment, payment_type: :refund)
      expect(payment.debit?).to be true
      expect(payment.credit?).to be false
    end
  end
end
