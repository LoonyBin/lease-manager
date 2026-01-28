# frozen_string_literal: true

require "rails_helper"

RSpec.describe "BankStatements" do
  describe "GET /bank_statements" do
    it "returns http success" do
      get bank_statements_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /bank_statements/new" do
    it "returns http success" do
      get new_bank_statement_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /bank_statements" do
    context "with valid parameters" do
      let(:file) { fixture_file_upload("spec/fixtures/files/statement.csv", "text/csv") }

      before do
        # Create a dummy CSV file for testing
        File.write("spec/fixtures/files/statement.csv", "date,amount,description,reference\n2025-01-01,100.00,Test,REF")
      end

      it "creates a new BankStatement and redirects" do # rubocop:disable RSpec/ExampleLength
        aggregate_failures do
          expect do
            post bank_statements_path, params: { bank_statement: { file: file } }
          end.to change(BankStatement, :count).by(1)
          expect(response).to redirect_to(BankStatement.last)
        end
      end
    end
  end

  describe "GET /bank_statements/:id" do
    let(:bank_statement) { create(:bank_statement) }

    it "returns http success" do
      get bank_statement_path(bank_statement)
      expect(response).to have_http_status(:success)
    end
  end
end
