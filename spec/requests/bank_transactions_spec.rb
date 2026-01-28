# frozen_string_literal: true

require "rails_helper"

RSpec.describe "BankTransactions" do
  let(:bank_statement) { create(:bank_statement) }
  let(:transaction) { create(:bank_transaction, bank_statement: bank_statement) }

  describe "PATCH /bank_transactions/:id/confirm" do
    it "confirms the transaction" do
      patch confirm_bank_transaction_path(transaction)
      expect(transaction.reload).to be_confirmed
    end

    it "redirects to the bank statement" do
      patch confirm_bank_transaction_path(transaction)
      expect(response).to redirect_to(bank_statement_path(bank_statement))
    end
  end

  describe "PATCH /bank_transactions/:id/reject" do
    it "rejects the transaction" do
      patch reject_bank_transaction_path(transaction)
      expect(transaction.reload).to be_rejected
    end

    it "redirects to the bank statement" do
      patch reject_bank_transaction_path(transaction)
      expect(response).to redirect_to(bank_statement_path(bank_statement))
    end
  end

  describe "PATCH /bank_transactions/:id/rematch" do
    before { transaction.rejected! }

    it "resets the transaction to unmatched" do
      patch rematch_bank_transaction_path(transaction)
      expect(transaction.reload).to be_unmatched
    end

    it "redirects to the bank statement" do
      patch rematch_bank_transaction_path(transaction)
      expect(response).to redirect_to(bank_statement_path(bank_statement))
    end
  end
end
