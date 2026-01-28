# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReconciliationMatcher do
  subject(:matcher) { described_class.new(bank_statement) }

  let(:bank_statement) { create(:bank_statement) }
  let!(:transaction) do
    create(:bank_transaction, bank_statement: bank_statement, date: Date.current, amount: 1000.0, reference: "REF123",
                              status: :unmatched)
  end
  let!(:matching_payment) do
    create(:payment, date: Date.current, amount: 1000.0, reference_number: "REF123", mode: :rtgs)
  end
  let!(:non_matching_payment) do
    create(:payment, date: Date.current, amount: 500.0, reference_number: "OTHER", mode: :rtgs)
  end

  describe "#call" do
    it "matches transaction to payment based on date, amount, and reference" do
      matcher.call
      expect(transaction.reload.matched_payment).to eq(matching_payment)
      expect(transaction).to be_matched
    end

    it "does not match if amount differs" do
      transaction.update!(amount: 999.0)
      matcher.call
      expect(transaction.reload.matched_payment).to be_nil
    end

    it "does not match if reference differs" do
      transaction.update!(reference: "NOMATCH")
      matcher.call
      expect(transaction.reload.matched_payment).to be_nil
    end

    it "matches if payment reference is contained in transaction description" do
      transaction.update!(reference: nil, description: "Payment REF123 received")
      matcher.call
      expect(transaction.reload.matched_payment).to eq(matching_payment)
    end
  end
end
