# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Invoice form lease authorization" do
  let(:user) { create(:user) }
  let(:own_lease) { create(:lease) }
  let(:foreign_lease) { create(:lease) }
  let(:date) { "2025-02-01" }

  before do
    create(:user_association, user: user, associable: own_lease.property.owner)
    sign_in_as(user)
  end

  def expect_denied_without(*fragments)
    expect(response).to redirect_to(root_path).or have_http_status(:forbidden)
    fragments.each { |text| expect(response.body).not_to include(text) }
  end

  describe "GET /invoices/new" do
    it "refuses a foreign lease without a date and leaks no identity" do
      get new_invoice_path(invoice: { lease_id: foreign_lease.id })
      expect_denied_without(foreign_lease.tenant.name, foreign_lease.property.name)
    end

    it "refuses a foreign lease with a date and generates nothing" do
      allow(TemplateInvoiceGenerator).to receive(:new).and_call_original
      get new_invoice_path(invoice: { lease_id: foreign_lease.id, date: date })
      expect(TemplateInvoiceGenerator).not_to have_received(:new)
    end

    it "does not reveal the line items of a foreign lease" do
      get new_invoice_path(invoice: { lease_id: foreign_lease.id, date: date })
      expect_denied_without("Rent for February 2025")
    end

    it "does not reuse a saved foreign invoice" do
      saved = create(:invoice, lease: foreign_lease, date: date)
      get new_invoice_path(invoice: { lease_id: foreign_lease.id, date: saved.date.to_s })
      expect(response).not_to have_http_status(:success)
    end

    it "refuses a nonexistent lease id" do
      get new_invoice_path(invoice: { lease_id: 0 })
      expect(response).not_to have_http_status(:success)
    end

    it "refuses a malformed lease id" do
      get new_invoice_path(invoice: { lease_id: "abc", date: date })
      expect(response).not_to have_http_status(:server_error)
    end

    it "refuses a foreign lease with an invalid date" do
      get new_invoice_path(invoice: { lease_id: foreign_lease.id, date: "not-a-date" })
      expect(response).not_to have_http_status(:success)
    end

    it "still prefills an owned lease" do
      get new_invoice_path(invoice: { lease_id: own_lease.id, date: date })
      expect(response.body).to include("Rent for February 2025")
    end

    it "still serves a blank form" do
      get new_invoice_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /invoices" do
    it "refuses a foreign lease without creating an invoice" do
      foreign_lease
      expect do
        post invoices_path, params: { invoice: { lease_id: foreign_lease.id, date: date } }
      end.not_to change(Invoice, :count)
    end

    it "refuses a nonexistent lease id" do
      post invoices_path, params: { invoice: { lease_id: 0, date: date } }
      expect(response).not_to have_http_status(:server_error)
    end
  end

  describe "admin" do
    it "can prefill any lease" do
      sign_in_admin
      get new_invoice_path(invoice: { lease_id: foreign_lease.id, date: date })
      expect(response).to have_http_status(:success)
    end
  end
end
