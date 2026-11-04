# frozen_string_literal: true

require "rails_helper"

RSpec.describe "BankTransactions" do
  let(:day) { Date.new(2026, 3, 10) }
  let(:payment) { create(:payment, amount: 1500, date: day, mode: :neft, reference_number: nil) }

  def line(status, **attrs)
    create(:bank_transaction, { amount: 1500, date: day, reference: nil, status: status }.merge(attrs))
  end

  context "when signed in as an admin" do
    before { sign_in_admin }

    it "confirms a matched line and redirects with a notice", :aggregate_failures do
      txn = line(:matched, matched_payment: payment)
      patch confirm_bank_transaction_path(txn)
      expect(txn.reload).to be_confirmed
      expect(response).to redirect_to(bank_statement_path(txn.bank_statement))
    end

    it "changes nothing on the payment when confirming" do
      txn = line(:matched, matched_payment: payment)
      footprint = -> { payment.reload.then { |p| [p.status, p.balance, p.entries.count] } }
      expect { patch confirm_bank_transaction_path(txn) }.not_to(change { footprint.call })
    end

    it "refuses to confirm an unmatched line with an alert", :aggregate_failures do
      txn = line(:unmatched)
      patch confirm_bank_transaction_path(txn)
      expect(txn.reload).to be_unmatched
      expect(flash[:alert]).to eq(I18n.t("bank_transactions.not_allowed"))
    end

    it "rejects a matched line" do
      txn = line(:matched, matched_payment: payment)
      patch reject_bank_transaction_path(txn)
      expect(txn.reload).to be_rejected
    end

    it "re-matches a rejected line" do
      txn = line(:rejected)
      payment
      patch rematch_bank_transaction_path(txn)
      expect(txn.reload).to have_attributes(status: "matched", matched_payment: payment)
    end

    it "undoes a confirmed line" do
      txn = line(:confirmed, matched_payment: payment)
      patch reject_bank_transaction_path(txn)
      expect(txn.reload).to be_rejected
    end

    context "with an ambiguous line" do
      let(:pair) { create_list(:payment, 2, amount: 1500, date: day, mode: :neft, reference_number: nil) }
      let!(:txn) { line(:ambiguous) }

      it "refuses a payment outside the candidates" do
        outside = create(:payment, amount: 7, date: day, mode: :neft)
        patch choose_bank_transaction_path(txn, payment_id: outside.id)
        expect(txn.reload).to be_ambiguous
      end

      it "confirms a chosen candidate" do
        patch choose_bank_transaction_path(txn, payment_id: pair.last.id)
        expect(txn.reload).to have_attributes(status: "confirmed", matched_payment: pair.last)
      end
    end

    context "with a linked payment" do
      let!(:txn) { line(:confirmed, matched_payment: payment) }

      it "lets the payment be deleted" do
        expect { delete payment_path(payment) }.to change(Payment, :count).by(-1)
      end

      it "releases the line when the payment is deleted" do
        delete payment_path(payment)
        expect(txn.reload).to be_unmatched
      end

      it "releases the line when the payment is rejected" do
        patch payment_path(payment), params: { payment: { status: "rejected" } }
        expect(txn.reload).to be_unmatched
      end

      it "releases the line when the payment amount is corrected" do
        patch payment_path(payment), params: { payment: { amount: 1600 } }
        expect(txn.reload).to be_unmatched
      end
    end
  end

  context "when not an admin" do
    let!(:txn) { line(:matched, matched_payment: payment) }

    %i[confirm reject rematch choose].each do |action|
      it "refuses #{action} to a plain user" do
        sign_in_user
        patch public_send(:"#{action}_bank_transaction_path", txn)
        expect(txn.reload).to be_matched
      end

      it "refuses #{action} when signed out" do
        patch public_send(:"#{action}_bank_transaction_path", txn)
        expect(txn.reload).to be_matched
      end
    end
  end
end
