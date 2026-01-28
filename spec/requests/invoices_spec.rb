# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Invoices" do
  describe "GET /invoices" do
    it "returns http success" do
      get invoices_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /invoices/:id" do
    it "returns http success" do
      get invoice_path(create(:invoice))
      expect(response).to have_http_status(:success)
    end
  end

  describe "PATCH /invoices/:id/finalize" do
    context "when invoice is draft" do
      it "finalizes the invoice and assigns a number", :aggregate_failures do
        invoice = create(:invoice, status: :draft, number: nil)
        patch finalize_invoice_path(invoice)

        expect(invoice.reload).to have_attributes(status: "finalized", number: be_present)
        expect(response).to redirect_to(invoice_path(invoice))
      end
    end

    context "when invoice is already finalized" do
      it "shows an error" do
        patch finalize_invoice_path(create(:invoice, status: :finalized))
        expect(flash[:alert]).to eq("Invoice is not in draft status.")
      end
    end
  end

  describe "GET /invoices/:id/edit" do
    it "returns http success" do
      get edit_invoice_path(create(:invoice))
      expect(response).to have_http_status(:success)
    end
  end

  describe "PATCH /invoices/:id" do
    context "with valid params" do
      let(:invoice) { create(:invoice) }
      let!(:line_item) { create(:line_item, invoice: invoice, name: "Original", amount: 10_000, category: "rent") }
      let(:params) do
        { invoice: { date: "2026-02-01",
                     line_items_attributes: { "0" => { id: line_item.id, name: "Updated", amount: 15_000,
                                                       category: "rent" } } } }
      end

      it "updates the invoice and nested line items", :aggregate_failures do
        patch invoice_path(invoice), params: params
        expect(invoice.reload.date).to eq(Date.new(2026, 2, 1))
        expect(line_item.reload).to have_attributes(name: "Updated", amount: 15_000)
      end
    end

    context "when deleting a line item" do
      it "removes the line item" do
        line_item = create(:line_item)
        params = { invoice: { line_items_attributes: { "0" => { id: line_item.id, _destroy: "1" } } } }
        expect { patch invoice_path(line_item.invoice), params: params }.to change(LineItem, :count).by(-1)
      end
    end

    context "when adding a new line item" do
      it "creates the line item" do
        invoice = create(:invoice)
        params = { invoice: { line_items_attributes: { "0" => { name: "New Fee", amount: 250, tax_rate: 10,
                                                                category: "other" } } } }
        expect { patch invoice_path(invoice), params: params }.to change(LineItem, :count).by(1)
      end
    end
  end
end
