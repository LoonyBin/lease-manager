# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Invoices" do
  let(:owner) { create(:owner, invoice_sequence: 10) }
  let(:property) { create(:property, owner: owner) }
  let(:lease) { create(:lease, property: property) }
  let(:invoice) { create(:invoice, lease: lease, status: :draft, number: nil) }

  describe "GET /invoices" do
    it "returns http success" do
      get invoices_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /invoices/:id" do
    it "returns http success" do
      get invoice_path(invoice)
      expect(response).to have_http_status(:success)
    end
  end

  describe "PATCH /invoices/:id/finalize" do
    context "when invoice is draft" do
      before { patch finalize_invoice_path(invoice) }

      it "finalizes the invoice" do
        invoice.reload
        expect(invoice).to have_attributes(status: "finalized", number: be_present)
      end

      it "redirects to invoice page" do
        expect(response).to redirect_to(invoice_path(invoice))
      end

      it "sets a success notice" do
        expect(flash[:notice]).to eq("Invoice finalized successfully.")
      end
    end

    context "when invoice is already finalized" do
      before { invoice.finalized! }

      it "does not change the invoice" do
        patch finalize_invoice_path(invoice)
        expect(flash[:alert]).to eq("Invoice is not in draft status.")
      end
    end
  end
end
