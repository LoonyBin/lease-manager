# frozen_string_literal: true

require "rails_helper"

RSpec.describe BankTransaction do
  subject(:bank_transaction) { build(:bank_transaction) }

  let(:day) { Date.new(2026, 3, 10) }
  let(:payment) { create(:payment, amount: 1500, date: day, mode: :neft, reference_number: nil) }

  def line(status, **attrs)
    create(:bank_transaction, { amount: 1500, date: day, status: status }.merge(attrs))
  end

  describe "audit trail" do
    it "keeps statement text out of versions", :aggregate_failures do
      txn = create(:bank_transaction, amount: 4321.5, date: day, description: "Rent from Asha Rao",
                                      reference: "UTR778899")
      txn.update!(description: "Edited narration Q", reference: "UTR112233", status: :rejected)
      serialized = txn.versions.reload.map { |v| [v.object, v.object_changes] }.join
      expect(serialized).not_to match(/4321|2026-03-10|Asha Rao|UTR778899|Edited narration Q|UTR112233/)
    end
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:date) }
    it { is_expected.to validate_presence_of(:amount) }
    it { is_expected.to validate_numericality_of(:amount).is_other_than(0) }

    it {
      expect(bank_transaction).to define_enum_for(:status).with_values(unmatched: 0, matched: 1, confirmed: 2,
                                                                       rejected: 3, ambiguous: 4)
    }

    it "requires a payment on a matched or confirmed line", :aggregate_failures do
      expect(build(:bank_transaction, status: :matched)).not_to be_valid
      expect(build(:bank_transaction, status: :confirmed)).not_to be_valid
    end

    it "refuses a payment on a line that is not matched or confirmed" do
      expect(build(:bank_transaction, status: :ambiguous, matched_payment: payment)).not_to be_valid
    end
  end

  describe "associations" do
    it { is_expected.to belong_to(:bank_statement) }
    it { is_expected.to belong_to(:matched_payment).optional }
  end

  describe "database guarantees" do
    # insert_all! skips the model validation, so these reach the database itself.
    def add_row(**attrs)
      now = Time.current
      row = { bank_statement_id: create(:bank_statement).id, date: day, amount: 1500, created_at: now,
              updated_at: now }
      described_class.insert_all!([row.merge(attrs)]) # rubocop:disable Rails/SkipsModelValidations -- testing the DB
    end

    it "refuses a second active claim on one payment" do
      line(:matched, matched_payment: payment)
      expect { add_row(status: described_class.statuses[:confirmed], matched_payment_id: payment.id) }
        .to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "allows a payment to be re-proposed after an earlier line was rejected" do
      line(:rejected)
      expect { line(:matched, matched_payment: payment) }.not_to raise_error
    end

    it "refuses a matched line with no payment" do
      expect { add_row(status: described_class.statuses[:matched]) }.to raise_error(ActiveRecord::StatementInvalid)
    end

    it "refuses a payment on an unmatched line" do
      expect { add_row(status: 0, matched_payment_id: payment.id) }.to raise_error(ActiveRecord::StatementInvalid)
    end
  end

  describe "transitions" do
    it "confirms a matched line and changes nothing on the payment", :aggregate_failures do
      matched = line(:matched, matched_payment: payment)
      footprint = -> { payment.reload.then { |p| [p.status, p.balance, p.entries.count] } }
      expect { matched.confirm! }.not_to(change { footprint.call })
      expect(matched.reload).to be_confirmed
    end

    it "refuses to confirm an unmatched, ambiguous, rejected or confirmed line", :aggregate_failures do
      %i[unmatched ambiguous rejected].each { |status| expect(line(status).confirm!).to be(false) }
      done = line(:confirmed, matched_payment: payment)
      expect(done.confirm!).to be(false)
      expect(done.reload).to be_confirmed
    end

    it "rejects a matched line and clears the link", :aggregate_failures do
      matched = line(:matched, matched_payment: payment)
      expect(matched.reject!).to be(true)
      expect([matched.reload.status, matched.matched_payment]).to eq(["rejected", nil])
    end

    it "rejects an ambiguous or confirmed line", :aggregate_failures do
      expect(line(:ambiguous).reject!).to be(true)
      expect(line(:confirmed, matched_payment: create(:payment, mode: :neft)).reject!).to be(true)
    end

    it "refuses to reject an unmatched or rejected line", :aggregate_failures do
      expect(line(:unmatched).reject!).to be(false)
      expect(line(:rejected).reject!).to be(false)
    end

    it "refuses to re-match a matched or confirmed line", :aggregate_failures do
      expect(line(:matched, matched_payment: payment).rematch!).to be(false)
      expect(line(:confirmed, matched_payment: create(:payment, mode: :neft)).rematch!).to be(false)
    end

    it "actually runs the matcher on re-match, picking up a payment confirmed since" do
      draft = create(:payment, amount: 1500, date: day, mode: :neft, reference_number: nil, status: :draft)
      txn = line(:unmatched)
      draft.update!(status: :confirmed)
      txn.rematch!
      expect(txn.reload).to have_attributes(status: "matched", matched_payment: draft)
    end

    it "stays rejected until re-match is asked for" do
      txn = line(:matched, matched_payment: payment)
      txn.reject!
      expect(txn.reload).to be_rejected
    end

    it "can re-propose a rejected payment when re-match is asked for" do
      txn = line(:rejected, amount: 1500, date: day)
      payment
      txn.rematch!
      expect(txn.reload.matched_payment).to eq(payment)
    end

    describe "#link!" do
      let(:txn) { line(:unmatched) }

      it "links a payment that still qualifies", :aggregate_failures do
        expect(txn.link!(payment, :matched)).to be(true)
        expect([txn.reload.status, txn.matched_payment]).to eq(["matched", payment])
      end

      it "refuses a payment that stopped qualifying after it was read", :aggregate_failures do
        stale = Payment.find(payment.id)
        payment.update!(status: :rejected)
        expect(txn.link!(stale, :matched)).to be(false)
        expect(txn.reload).to be_unmatched
      end

      it "locks the payment row before checking it" do
        queries = []
        callback = ->(*, payload) { queries << payload[:sql] }
        ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { txn.link!(payment, :matched) }
        expect(queries.grep(/FROM "payments".*FOR UPDATE/m)).not_to be_empty
      end

      it "refuses to confirm a chosen payment that was rejected meanwhile" do
        ambiguous = line(:ambiguous)
        stale = Payment.find(payment.id)
        payment.update!(status: :rejected)
        expect(ambiguous.choose!(stale)).to be(false)
      end
    end

    describe "#choose!" do
      let!(:first) { create(:payment, amount: 1500, date: day, mode: :neft, reference_number: nil) }
      let!(:second) { create(:payment, amount: 1500, date: day, mode: :neft, reference_number: nil) }
      let(:txn) { line(:ambiguous) }

      it "confirms one of the line's candidates", :aggregate_failures do
        expect(txn.choose!(second)).to be(true)
        expect([txn.reload.status, txn.matched_payment]).to eq(["confirmed", second])
      end

      it "refuses a payment outside the candidates", :aggregate_failures do
        outside = create(:payment, amount: 99, date: day, mode: :neft)
        expect(txn.choose!(outside)).to be(false)
        expect(txn.choose!(nil)).to be(false)
        expect(txn.reload).to be_ambiguous
      end

      it "refuses a line that is not ambiguous" do
        expect(line(:unmatched).choose!(first)).to be(false)
      end

      it "refuses a payment another line has since claimed" do
        line(:confirmed, matched_payment: second)
        expect(txn.choose!(second)).to be(false)
      end
    end

    describe "lock order" do
      # A payment edit locks the payment and then updates the line, so linking
      # must never hold the line lock while waiting for the payment lock.
      def lock_order(&)
        locks = []
        callback = lambda do |*, payload|
          sql = payload[:sql]
          next unless sql.include?("FOR UPDATE")

          locks << :payment if sql.include?('FROM "payments"')
          locks << :line if sql.include?('FROM "bank_transactions"')
        end
        ActiveSupport::Notifications.subscribed(callback, "sql.active_record", &)
        locks.chunk_while { |a, b| a == b }.map(&:first)
      end

      let!(:candidate) { create(:payment, amount: 1500, date: day, mode: :neft, reference_number: nil) }

      it "locks the payment before the line on Choose" do
        create(:payment, amount: 1500, date: day, mode: :neft, reference_number: nil)
        txn = line(:ambiguous)
        expect(lock_order { txn.choose!(candidate) }).to eq(%i[payment line])
      end

      # The first line lock is the reset, which commits before matching starts.
      it "takes the payment lock before the line lock when linking from Re-match" do
        txn = line(:rejected)
        expect(lock_order { txn.rematch! }).to eq(%i[line payment line])
      end

      it "does not link a line that was rejected after the caller read it" do
        txn = line(:unmatched)
        stale = described_class.find(txn.id)
        txn.update!(status: :rejected)
        expect(stale.link!(candidate, :matched)).to be(false)
      end
    end
  end
end
