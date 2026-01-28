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
      invoice = create(:invoice)
      get invoice_path(invoice)
      expect(response).to have_http_status(:success)
    end
  end

  describe "PATCH /invoices/:id/finalize" do
    context "when invoice is draft" do
      it "finalizes the invoice and assigns a number" do
        invoice = create(:invoice, status: :draft, number: nil)
        patch finalize_invoice_path(invoice)

        invoice.reload
        expect(invoice).to have_attributes(status: "finalized", number: be_present)
        expect(response).to redirect_to(invoice_path(invoice))
        expect(flash[:notice]).to eq("Invoice finalized successfully.")
      end
    end

    context "when invoice is already finalized" do
      it "does not change the invoice" do
        invoice = create(:invoice, status: :finalized)
        patch finalize_invoice_path(invoice)
        expect(flash[:alert]).to eq("Invoice is not in draft status.")
      end
    end
  end

  describe "GET /invoices/:id/edit" do
    it "returns http success" do
      invoice = create(:invoice)
      get edit_invoice_path(invoice)
      expect(response).to have_http_status(:success)
    end
  end

  describe "PATCH /invoices/:id" do
    context "with valid params" do
      it "updates the invoice and nested line items" do
        invoice = create(:invoice)
        line_item = create(:line_item, invoice: invoice, name: "Original Rent", amount: 10_000, category: "rent")

        params = {
          invoice: {
            date: "2026-02-01",
            status: "draft",
            line_items_attributes: {
              "0" => { id: line_item.id, name: "Updated Rent", amount: 15_000, category: "rent" }
            }
          }
        }

        patch invoice_path(invoice), params: params

        invoice.reload
        line_item.reload
        expect(invoice.date).to eq(Date.new(2026, 2, 1))
        expect(line_item).to have_attributes(name: "Updated Rent", amount: 15_000)
        expect(response).to redirect_to(invoice_path(invoice))
        expect(flash[:notice]).to eq("Invoice was successfully updated.")
      end
    end

    context "when deleting a line item" do
      it "removes the line item" do
        invoice = create(:invoice)
        line_item = create(:line_item, invoice: invoice)

        params = {
          invoice: {
            line_items_attributes: {
              "0" => { id: line_item.id, _destroy: "1" }
            }
          }
        }

        expect { patch invoice_path(invoice), params: params }.to change(LineItem, :count).by(-1)
      end
    end
  end
end
