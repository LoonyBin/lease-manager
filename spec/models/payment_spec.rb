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
    it { is_expected.to define_enum_for(:status).with_values(draft: 0, confirmed: 1).with_default(:confirmed) }
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
      payment = create(:payment, lease: lease, amount: 100, status: :confirmed)
      expect(SettlementService).to have_received(:auto_settle).with(payment)
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

    it "does not create duplicate entries if already confirmed" do
      confirmed_payment = create(:payment, lease: lease, amount: 50, status: :confirmed)
      initial_entry_count = confirmed_payment.entries.count

      confirmed_payment.update!(status: :confirmed)

      expect(confirmed_payment.entries.count).to eq(initial_entry_count)
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
