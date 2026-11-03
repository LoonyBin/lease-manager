# frozen_string_literal: true

require "rails_helper"

# A bank line must never keep pointing at a payment that has stopped being a
# valid match, and a linked payment must stay deletable.
RSpec.describe Payment, "bank line links" do # rubocop:disable RSpec/DescribeMethod
  let(:day) { Date.new(2026, 3, 10) }
  let(:payment) { create(:payment, amount: 1500, date: day, mode: :neft, reference_number: "UTR1") }

  %i[matched confirmed].each do |status|
    context "with a #{status} line" do
      let!(:line) do
        create(:bank_transaction, status: status, matched_payment: payment, amount: 1500, date: day, reference: "UTR1")
      end

      def expect_released
        expect([line.reload.status, line.matched_payment]).to eq(["unmatched", nil])
      end

      it "releases the line when the payment is rejected" do
        payment.update!(status: :rejected)
        expect_released
      end

      it "releases the line when the amount changes" do
        payment.update!(amount: 1600)
        expect_released
      end

      it "releases the line when the date moves out of the window" do
        payment.update!(date: day + 10)
        expect_released
      end

      it "releases the line when the payment becomes cash" do
        payment.update!(mode: :cash)
        expect_released
      end

      it "releases the line when the payment becomes a refund" do
        payment.update!(payment_type: :refund)
        expect_released
      end

      it "releases the line when the reference now conflicts" do
        payment.update!(reference_number: "OTHER")
        expect_released
      end

      it "keeps the link when an edit leaves the payment qualifying" do
        payment.update!(date: day + 1, reference_number: "UTR1")
        expect(line.reload.matched_payment).to eq(payment)
      end

      it "keeps the link when the payment moves to another lease" do
        payment.update!(lease: create(:lease))
        expect(line.reload.matched_payment).to eq(payment)
      end

      it "lets the payment be deleted and releases the line" do
        expect { payment.destroy! }.not_to raise_error
        expect_released
      end

      it "lets the lease be deleted" do
        expect { payment.lease.destroy! }.not_to raise_error
        expect_released
      end

      it "rolls the payment change back if releasing fails", :aggregate_failures do
        allow(BankTransaction).to receive(:release_links_for).and_raise(ActiveRecord::StatementInvalid)
        expect { payment.update!(amount: 1600) }.to raise_error(ActiveRecord::StatementInvalid)
        expect(payment.reload.amount).to eq(1500)
      end
    end
  end

  it "releases the line through Payments::Correction" do
    line = create(:bank_transaction, status: :confirmed, matched_payment: payment, amount: 1500, date: day,
                                     reference: "UTR1")
    Payments::Correction.call(payment, { amount: 1700 })
    expect(line.reload).to be_unmatched
  end
end
