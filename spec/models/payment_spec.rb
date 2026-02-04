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
  end

  describe "callbacks" do
    let(:lease) { create(:lease) }

    describe "initial entry creation" do
      it "creates an initial entry when created" do
        payment = create(:payment, lease: lease, amount: 100)
        expect(payment.entries.initial.count).to eq(1)
      end

      it "sets balance from entry amount" do
        payment = create(:payment, lease: lease, amount: 100)
        expect(payment.balance).to eq(-100)
      end
    end

    describe "auto settlement" do
      it "auto-settles after creation" do
        allow(SettlementService).to receive(:auto_settle)
        payment = create(:payment, lease: lease, amount: 100)
        expect(SettlementService).to have_received(:auto_settle).with(payment)
      end
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
