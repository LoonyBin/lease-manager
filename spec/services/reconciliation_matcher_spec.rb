# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReconciliationMatcher do
  let(:statement) { create(:bank_statement) }
  let(:day) { Date.new(2026, 3, 10) }

  # Mode is set explicitly: the payment factory picks one at random, and cash
  # would make these examples flaky.
  def payment(**attrs)
    create(:payment, { amount: 1500, date: day, mode: :neft, reference_number: nil }.merge(attrs))
  end

  def line(**attrs)
    create(:bank_transaction, { bank_statement: statement, amount: 1500, date: day, reference: nil,
                                description: "Rent" }.merge(attrs))
  end

  def run(*lines)
    described_class.new(statement).call
    lines.each(&:reload)
  end

  describe "eligibility" do
    it "proposes a confirmed payment with the same amount on the same day" do
      candidate = payment
      txn = line
      run(txn)
      expect([txn.status, txn.matched_payment]).to eq(["matched", candidate])
    end

    %i[partially_allocated fully_allocated].each do |status|
      it "proposes a #{status} payment" do
        candidate = payment(status: :confirmed)
        # update_column keeps the allocation status as the app itself writes it
        candidate.update_column(:status, Payment.statuses.fetch(status)) # rubocop:disable Rails/SkipsModelValidations
        txn = line
        run(txn)
        expect(txn.matched_payment).to eq(candidate)
      end
    end

    it "never proposes draft or rejected payments" do
      payment(status: :draft)
      payment(status: :rejected)
      txn = line
      run(txn)
      expect(txn).to be_unmatched
    end

    it "never proposes cash or tax-deducted-at-source payments" do
      payment(mode: :cash)
      payment(mode: :tax_deducted_at_source)
      txn = line
      run(txn)
      expect(txn).to be_unmatched
    end

    it "requires the exact amount" do
      payment(amount: 1500.01)
      txn = line
      run(txn)
      expect(txn).to be_unmatched
    end

    [-3, 3].each do |offset|
      it "accepts a payment exactly #{offset.abs} days #{offset.negative? ? 'before' : 'after'}" do
        candidate = payment(date: day + offset)
        txn = line
        run(txn)
        expect(txn.matched_payment).to eq(candidate)
      end
    end

    it "rejects a payment four days away" do
      payment(date: day + 4)
      txn = line
      run(txn)
      expect(txn).to be_unmatched
    end
  end

  describe "direction" do
    it "does not match a bank credit to a refund" do
      payment(payment_type: :refund)
      txn = line
      run(txn)
      expect(txn).to be_unmatched
    end

    it "does not match a bank debit to a receipt" do
      payment
      txn = line(amount: -1500)
      run(txn)
      expect(txn).to be_unmatched
    end

    it "matches a bank debit to a refund" do
      refund = payment(payment_type: :refund)
      txn = line(amount: -1500)
      run(txn)
      expect(txn.matched_payment).to eq(refund)
    end
  end

  describe "references" do
    it "ignores references when the payment has none" do
      candidate = payment
      txn = line(reference: "ANY")
      run(txn)
      expect(txn.matched_payment).to eq(candidate)
    end

    it "treats a matching bank reference as reference-confirmed, ignoring case", :aggregate_failures do
      candidate = payment(reference_number: "utr123")
      txn = line(reference: " UTR123 ")
      expect(described_class.candidates(txn).map(&:basis)).to eq([:reference])
      run(txn)
      expect(txn.matched_payment).to eq(candidate)
    end

    it "finds the payment reference in the description when the bank reference differs" do
      payment(reference_number: "UTR123")
      found = described_class.candidates(line(reference: "OTHER", description: "NEFT UTR123 rent"))
      expect(found.map(&:basis)).to eq([:reference])
    end

    it "is not a candidate when the bank reference conflicts and the description lacks it" do
      payment(reference_number: "UTR123")
      expect(described_class.candidates(line(reference: "UTR999", description: "rent"))).to be_empty
    end

    it "does not take a different reference named in the description as a match" do
      payment(reference_number: "UTR123")
      expect(described_class.candidates(line(reference: "UTR999", description: "ref UTR999"))).to be_empty
    end

    it "does not find 123 inside UTR991234" do
      payment(reference_number: "123")
      expect(described_class.candidates(line(reference: "UTR991234"))).to be_empty
    end

    it "uses the description when the bank reference is blank" do
      payment(reference_number: "UTR123")
      expect(described_class.candidates(line(description: "rent utr123")).map(&:basis)).to eq([:reference])
    end

    it "falls back to date and amount when the bank reference and description are silent" do
      payment(reference_number: "UTR123")
      expect(described_class.candidates(line(description: "rent")).map(&:basis)).to eq([:date_amount])
    end
  end

  describe "several candidates" do
    it "never links when two payments qualify" do
      payment
      payment
      txn = line
      run(txn)
      expect([txn.status, txn.matched_payment]).to eq(["ambiguous", nil])
    end

    [false, true].each do |reversed|
      it "gives ambiguous results when the rows were created #{reversed ? 'in reverse' : 'in order'}" do
        pays = Array.new(2) { payment }
        txns = (reversed ? pays.reverse : pays).map { line }
        run(*txns)
        expect(txns.map(&:status)).to eq(%w[ambiguous ambiguous])
      end
    end

    it "makes both lines ambiguous when two lines seek one payment" do
      payment
      a = line
      b = line
      run(a, b)
      expect([a.status, b.status]).to eq(%w[ambiguous ambiguous])
    end

    it "lets a reference-confirmed line take the payment over a date-and-amount line" do
      candidate = payment(reference_number: "UTR123")
      confirmed_by_ref = line(reference: "UTR123")
      other = line(description: "rent")
      run(confirmed_by_ref, other)
      expect([confirmed_by_ref.matched_payment, other.status]).to eq([candidate, "unmatched"])
    end

    it "leaves payments sought by an ambiguous reference line out of the second pass" do
      create_list(:payment, 2, amount: 1500, date: day, mode: :neft, reference_number: "UTR123")
      lines = [line(reference: "UTR123"), line(description: "rent")]
      run(*lines)
      expect(lines.map(&:status)).to eq(%w[ambiguous unmatched])
    end
  end

  describe "availability" do
    it "does not propose a payment already matched or confirmed on another statement" do
      candidate = payment
      create(:bank_transaction, status: :confirmed, matched_payment: candidate)
      txn = line
      run(txn)
      expect(txn).to be_unmatched
    end

    it "proposes a payment whose earlier line was rejected" do
      candidate = payment
      create(:bank_transaction, status: :rejected)
      txn = line
      run(txn)
      expect(txn.matched_payment).to eq(candidate)
    end

    it "leaves rejected and confirmed lines untouched" do
      candidate = payment
      rejected = line(status: :rejected)
      confirmed = line(status: :confirmed, matched_payment: candidate)
      run(rejected, confirmed)
      expect([rejected.status, confirmed.status, confirmed.matched_payment]).to eq(["rejected", "confirmed", candidate])
    end

    it "leaves the line unmatched when another claim wins the race" do
      payment
      txn = line
      allow(txn).to receive(:update!).and_raise(ActiveRecord::RecordNotUnique)
      allow(txn).to receive(:reload).and_return(txn)
      expect { described_class.new([txn]).call }.not_to(change(txn, :status))
    end
  end
end
