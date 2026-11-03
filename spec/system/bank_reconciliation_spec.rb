# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Bank reconciliation" do
  let(:admin) { create(:user, :admin) }
  let(:day) { Date.new(2026, 3, 10) }
  let!(:payment) { create(:payment, amount: 1500, date: day, mode: :neft, reference_number: "UTR1") }
  let(:csv_path) do
    Rails.root.join("tmp/bank_reconciliation_system_spec.csv").tap do |path|
      File.write(path, "date,amount,description,reference\n2026-03-10,\"Rs. 1,500.00\",Rent,UTR1\n")
    end
  end

  after { FileUtils.rm_f(csv_path) }

  it "uploads a statement, shows a proposal and confirms it without touching the payment" do
    status_before = payment.reload.status
    sign_in_through_browser(admin)
    visit new_bank_statement_path
    attach_file "bank_statement_file", csv_path
    click_button "Upload & Process"
    expect(page).to have_text("Reference matched")
    expect(page).to have_text("₹1,500.00")
    click_button "Confirm"
    expect(page).to have_text("Match confirmed.")
    expect(BankTransaction.last).to have_attributes(status: "confirmed", matched_payment: payment)
    expect(payment.reload.status).to eq(status_before)
  end
end
