# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentsHelper do
  describe "#reject_confirmation_prompt" do
    it "omits the removal warning for a draft payment (no ledger footprint)" do
      payment = build(:payment, status: :draft, payment_type: :payment)
      expect(helper.reject_confirmation_prompt(payment)).to eq("Reject this payment?")
    end

    it "names the refund and omits the removal warning for a draft refund" do
      payment = build(:payment, status: :draft, payment_type: :refund)
      expect(helper.reject_confirmation_prompt(payment)).to eq("Reject this refund?")
    end

    it "warns about credits, not invoices, for an allocated refund" do
      payment = build(:payment, status: :confirmed, payment_type: :refund)
      expect(helper.reject_confirmation_prompt(payment))
        .to eq("Reject this refund? This removes it from every credit it has drawn from.")
    end

    it "warns about invoices for an allocated payment" do
      payment = build(:payment, status: :confirmed, payment_type: :payment)
      expect(helper.reject_confirmation_prompt(payment))
        .to eq("Reject this payment? This removes it from every invoice it has paid.")
    end
  end
end
