# frozen_string_literal: true

require "rails_helper"

RSpec.describe BankStatementParser do
  subject(:parser) { described_class.new(bank_statement) }

  let(:bank_statement) { create(:bank_statement) }
  let(:csv_content) do
    <<~CSV
      date,amount,description,reference
      2025-01-01,1000.00,Rent Payment,REF001
      2025-01-02,-50.00,Service Charge,
    CSV
  end

  before do
    bank_statement.file.attach(io: StringIO.new(csv_content), filename: "statement.csv", content_type: "text/csv")
  end

  describe "#call" do
    it "creates bank transactions from CSV" do
      expect { parser.call }.to change(BankTransaction, :count).by(2)
    end

    it "sets transaction attributes correctly" do # rubocop:disable RSpec/ExampleLength
      parser.call
      transaction = BankTransaction.first
      aggregate_failures do
        expect(transaction.date).to eq(Date.parse("2025-01-01"))
        expect(transaction.amount).to eq(1000.00)
        expect(transaction.description).to eq("Rent Payment")
        expect(transaction.reference).to eq("REF001")
      end
    end

    it "updates bank statement status to processed" do
      parser.call
      expect(bank_statement.reload).to be_processed
    end
  end
end
