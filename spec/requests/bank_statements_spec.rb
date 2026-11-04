# frozen_string_literal: true

require "rails_helper"

RSpec.describe "BankStatements" do
  def upload(body, name: "statement.csv")
    file = Rack::Test::UploadedFile.new(StringIO.new(body), "text/csv", original_filename: name)
    post bank_statements_path, params: { bank_statement: { file: file } }
  end

  context "when signed in as an admin" do
    before { sign_in_admin }

    describe "GET /bank_statements" do
      it "lists statements" do
        statement = create(:bank_statement, filename: "march.csv")
        get bank_statements_path
        expect(response.body).to include(statement.filename)
      end
    end

    describe "GET /bank_statements/new" do
      it "returns http success" do
        get new_bank_statement_path
        expect(response).to have_http_status(:success)
      end
    end

    describe "POST /bank_statements" do
      let(:csv) { "date,amount,description,reference\n2026-03-10,\"Rs. 1,500.00\",Rent,UTR1\n2026-03-11,-200,Fee,\n" }

      it "imports the statement and its lines and redirects to it", :aggregate_failures do
        expect { upload(csv) }.to change(BankTransaction, :count).by(2)
        expect(response).to redirect_to(BankStatement.last)
        expect(BankTransaction.pluck(:amount)).to contain_exactly(1500, -200)
      end

      it "proposes a match for a qualifying payment" do
        payment = create(:payment, amount: 1500, date: Date.new(2026, 3, 10), mode: :neft, reference_number: "UTR1")
        upload(csv)
        expect(BankTransaction.find_by(reference: "UTR1")).to have_attributes(status: "matched",
                                                                              matched_payment: payment)
      end

      it "imports non-ASCII text after a byte-order mark" do
        upload("﻿date,amount,description\n2026-03-10,10,किराया\n")
        expect(BankTransaction.last.description).to eq("किराया")
      end

      it "saves nothing and names the row when a row is unreadable", :aggregate_failures do
        bad = "date,amount\n2026-03-10,10\n2026-03-11,\"1,000.00 Dr\"\n"
        expect { upload(bad) }.not_to(change { [BankStatement.count, BankTransaction.count] })
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("Row 3")
      end

      it "refuses an oversized upload from its reported size", :aggregate_failures do
        stub_const("BankStatementParser::MAX_BYTES", 10)
        expect { upload("date,amount\n2026-03-10,10\n") }.not_to(change(BankStatement, :count))
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("larger than")
      end

      it "keeps the uploaded file name out of the request log" do
        logged = []
        allow(Rails.logger).to receive(:info) { |*args, &blk| logged << (args.first || blk&.call).to_s }
        upload("date,amount\n2026-03-10,10\n", name: "acct-50100123456789.csv")
        expect(logged.join("\n")).not_to include("50100123456789")
      end

      it "answers 422 when no file is chosen", :aggregate_failures do
        post bank_statements_path, params: { bank_statement: { file: "" } }
        expect(response).to have_http_status(:unprocessable_content)
        expect(BankStatement.count).to eq(0)
      end
    end

    describe "GET /bank_statements/:id" do
      let(:statement) { create(:bank_statement) }
      let(:day) { Date.new(2026, 3, 10) }
      let!(:payments) do
        create_list(:payment, 2, amount: 1500.5, date: day, mode: :neft, reference_number: "UTR1")
      end

      def line(**attrs)
        create(:bank_transaction, { bank_statement: statement, amount: 1500.5, date: day }.merge(attrs))
      end

      it "shows rupee amounts with paise, the payment link and the match basis", :aggregate_failures do
        line(reference: "UTR1", status: :matched, matched_payment: payments.first)
        get bank_statement_path(statement)
        expect(response.body).to include("₹1,500.50", payment_path(payments.first), "Reference matched")
        expect(response.body).not_to include("$1,500")
      end

      it "lists candidates with a Choose button on ambiguous lines" do
        line(reference: "UTR1", status: :ambiguous)
        get bank_statement_path(statement)
        expect(response.body.scan("Choose").size).to eq(payments.size)
      end
    end
  end

  context "when not an admin" do
    before { sign_in_user }

    it "refuses the list" do
      get bank_statements_path
      expect(response).not_to have_http_status(:success)
    end

    it "refuses a statement" do
      get bank_statement_path(create(:bank_statement))
      expect(response).not_to have_http_status(:success)
    end

    it "refuses an upload" do
      expect { upload("date,amount\n2026-03-10,1") }.not_to change(BankStatement, :count)
    end

    it "shows no navigation link" do
      get root_path
      expect(response.body).not_to include(bank_statements_path)
    end
  end

  it "shows admins the navigation link" do
    sign_in_admin
    get root_path
    expect(response.body).to include(bank_statements_path)
  end
end
