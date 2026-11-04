# frozen_string_literal: true

require "rails_helper"

RSpec.describe BankStatementPurger do
  let(:day) { Date.new(2026, 3, 10) }
  let(:old) { create(:bank_statement, uploaded_at: 90.days.ago) }

  def line(statement, **attrs)
    create(:bank_transaction, { bank_statement: statement, amount: 1500, date: day, reference: nil }.merge(attrs))
  end

  def payment(**attrs)
    create(:payment, { amount: 1500, date: day, mode: :neft, reference_number: nil }.merge(attrs))
  end

  def confirmed_line(statement)
    candidate = payment
    txn = line(statement, status: :matched, matched_payment: candidate)
    txn.confirm!
    [txn, candidate]
  end

  def run = described_class.new.call

  it "deletes unmatched, matched, ambiguous and rejected lines on a statement 90 days old", :aggregate_failures do
    candidate = payment
    lines = [line(old), line(old, status: :matched, matched_payment: candidate),
             line(old, status: :ambiguous), line(old, status: :rejected)]
    run
    expect(BankTransaction.where(id: lines.map(&:id))).to be_empty
  end

  it "keeps every line of a statement under 90 days old, whatever the line's own date", :aggregate_failures do
    young = create(:bank_statement, uploaded_at: 90.days.ago + 1.minute)
    txn = line(young, date: 1.year.ago.to_date)
    run
    expect(txn.reload).to be_persisted
    expect(young.reload).to be_persisted
  end

  it "keeps a confirmed line and its statement while deleting unconfirmed siblings", :aggregate_failures do
    kept, = confirmed_line(old)
    gone = line(old)
    run
    expect(BankTransaction.where(id: [kept.id, gone.id])).to contain_exactly(kept)
    expect(old.reload).to be_persisted
  end

  it "deletes an emptied statement in the same run and leaves a young one alone" do
    young = create(:bank_statement)
    line(old)
    line(young)
    run
    expect(BankStatement.where(id: [old.id, young.id])).to contain_exactly(young)
  end

  describe "a confirmed line that stops being confirmed" do
    it "goes at the next run when its payment is destroyed", :aggregate_failures do
      txn, candidate = confirmed_line(old)
      candidate.destroy!
      run
      expect(BankTransaction.exists?(txn.id)).to be(false)
      expect(BankStatement.exists?(old.id)).to be(false)
    end

    it "goes at the next run when its payment no longer qualifies" do
      txn, candidate = confirmed_line(old)
      candidate.update!(amount: 999)
      run
      expect(BankTransaction.exists?(txn.id)).to be(false)
    end

    it "goes at the next run after Undo" do
      txn, = confirmed_line(old)
      txn.reject!
      run
      expect(BankTransaction.exists?(txn.id)).to be(false)
    end
  end

  it "leaves the payment untouched when deleting its matched line", :aggregate_failures do
    candidate = payment
    line(old, status: :matched, matched_payment: candidate)
    footprint = -> { candidate.reload.then { |p| [p.status, p.balance, p.entries.count] } }
    expect { run }.not_to(change { footprint.call })
    expect(line(create(:bank_statement)).link!(candidate, :matched)).to be(true)
  end

  it "does not delete a line that is confirmed when it is re-read" do
    txn, = confirmed_line(old)
    BankTransaction.destroy_unless_confirmed(txn.id)
    expect(BankTransaction.exists?(txn.id)).to be(true)
  end

  describe "audit versions" do
    let(:statement) { create(:bank_statement, uploaded_at: 90.days.ago, filename: "acct-98765.csv") }
    let(:versions) { PaperTrail::Version.where(event: "destroy", item_type: %w[BankTransaction BankStatement]) }

    before do
      line(statement, amount: 4321.5, description: "SECRETDESC", reference: "SECRETREF")
      run
    end

    it "record both deletions" do
      expect(versions.map(&:item_type)).to match_array(%w[BankTransaction BankStatement])
    end

    it "hold no statement text" do
      text = versions.map { |v| [v.object, v.object_changes].join }.join
      expect(text).not_to match(/4321|SECRETDESC|SECRETREF|acct-98765|#{day.iso8601}/)
    end
  end

  it "does nothing and raises on a repeat run", :aggregate_failures do
    line(old)
    run
    expect { run }.not_to(change { [BankTransaction.count, BankStatement.count, PaperTrail::Version.count] })
  end
end
