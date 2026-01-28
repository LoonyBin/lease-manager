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

  describe "GET /invoices/:id/edit" do
    it "returns http success" do
      get edit_invoice_path(invoice)
      expect(response).to have_http_status(:success)
    end
  end

  describe "PATCH /invoices/:id" do
    let!(:line_item) { create(:line_item, invoice: invoice, name: "Original Rent", amount: 10_000, category: "rent") }

    context "with valid params" do
      let(:params) do
        {
          invoice: {
            date: "2026-02-01",
            status: "draft",
            line_items_attributes: {
              "0" => { id: line_item.id, name: "Updated Rent", amount: 15_000, category: "rent" }
            }
          }
        }
      end

      it "updates the invoice date" do
        patch invoice_path(invoice), params: params
        invoice.reload
        expect(invoice.date).to eq(Date.new(2026, 2, 1))
      end

      it "updates the line item" do
        patch invoice_path(invoice), params: params
        line_item.reload
        expect(line_item).to have_attributes(name: "Updated Rent", amount: 15_000)
      end

      it "redirects to the invoice" do
        patch invoice_path(invoice), params: params
        expect(response).to redirect_to(invoice_path(invoice))
      end

      it "sets a success notice" do
        patch invoice_path(invoice), params: params
        expect(flash[:notice]).to eq("Invoice was successfully updated.")
      end
    end

    context "when deleting a line item" do
      let(:params) do
        {
          invoice: {
            line_items_attributes: {
              "0" => { id: line_item.id, _destroy: "1" }
            }
          }
        }
      end

      it "removes the line item" do
        expect { patch invoice_path(invoice), params: params }.to change(LineItem, :count).by(-1)
      end
    end
  end
end
