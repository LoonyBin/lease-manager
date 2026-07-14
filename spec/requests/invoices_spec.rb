# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Invoices" do
  before { sign_in_admin }

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

  describe "GET /invoices/new" do
    it "returns http success for empty new" do
      get new_invoice_path
      expect(response).to have_http_status(:success)
    end

    context "with generation params" do
      let(:lease) { create(:lease) }
      let(:date) { "2025-02-01" }

      it "returns valid prefilled invoice" do
        get new_invoice_path(invoice: { lease_id: lease.id, date: date })
        expect(response).to have_http_status(:success)
      end

      it "prefills line items from the lease's default template" do
        get new_invoice_path(invoice: { lease_id: lease.id, date: date })
        expect(response.body).to include("Rent for February 2025")
      end

      it "offers the lease's templates for prefilling" do
        get new_invoice_path(invoice: { lease_id: lease.id, date: date })
        expect(response.body).to include("invoice[invoice_template_id]")
      end

      it "prefills from an explicitly selected template" do
        template = create(:invoice_template, lease: lease, name: "Maintenance")
        template.line_items.first.update!(name: "Fixed maintenance charge", amount_expression: "2500",
                                          category: "maintenance")
        get new_invoice_path(invoice: { lease_id: lease.id, date: date, invoice_template_id: template.id })
        expect(response.body).to include("Fixed maintenance charge")
      end

      it "falls back to a blank form when the template expression fails to evaluate" do
        lease.invoice_templates.first.line_items.first.update!(amount_expression: "rent / (n - n)")
        get new_invoice_path(invoice: { lease_id: lease.id, date: date })
        expect(response).to have_http_status(:success)
      end

      it "falls back to a blank form for a stale template id" do
        get new_invoice_path(invoice: { lease_id: lease.id, date: date, invoice_template_id: -1 })
        expect(response).to have_http_status(:success)
      end
    end

    context "with document_type=credit_note" do
      it "returns success with credit note title", :aggregate_failures do
        get new_invoice_path(invoice: { document_type: "credit_note" })
        expect(response).to have_http_status(:success)
        expect(response.body).to include("New Credit Note")
      end
    end
  end

  describe "GET /invoices/:id/edit" do
    it "returns http success" do
      get edit_invoice_path(create(:invoice))
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /invoices" do
    context "with document_type credit_note" do
      let(:lease) { create(:lease) }

      it "creates a credit note", :aggregate_failures do
        params = { invoice: { lease_id: lease.id, date: Date.current, document_type: "credit_note",
                              line_items_attributes: { "0" => { name: "Refund", amount: 500, tax_rate: 0,
                                                                category: "other" } } } }
        expect { post invoices_path, params: params }.to change(Invoice, :count).by(1)
        expect(Invoice.last).to be_credit_note
      end
    end
  end

  describe "GET /invoices/:id (credit note)" do
    it "shows Credit Note in the page" do
      credit_note = create(:invoice, :credit_note)
      get invoice_path(credit_note)
      expect(response.body).to include("Credit Note")
    end
  end

  describe "GET /invoices/audit" do
    it "returns http success" do
      get audit_invoices_path
      expect(response).to have_http_status(:success)
    end

    context "when there are missing invoices" do
      let(:today) { Date.current }
      let!(:lease) { create(:lease, start_date: today - 1.month, duration_months: 12) }

      it "displays missing invoices in the page" do
        get audit_invoices_path
        expect(response.body).to include(CGI.escapeHTML(lease.tenant.name))
      end
    end
  end

  describe "POST /invoices (JSON)" do
    let(:lease) { create(:lease) }
    let(:date) { lease.start_date.next_month.beginning_of_month }
    let(:params) do
      { invoice: { lease_id: lease.id, date: date.iso8601,
                   status: "draft", document_type: "invoice" } }
    end

    it "creates a draft invoice with line items and returns JSON", :aggregate_failures do
      post invoices_path(format: :json), params: params, as: :json
      expect(response).to have_http_status(:success)
      expect(response.parsed_body["status"]).to eq("draft")
      expect(Invoice.find(response.parsed_body["id"]).line_items).to be_present
    end

    context "with an explicit invoice_template_id (audit page flow)" do
      let(:template) { lease.invoice_templates.first }
      let(:params) do
        { invoice: { lease_id: lease.id, invoice_template_id: template.id,
                     date: date.iso8601,
                     status: "draft", document_type: "invoice" } }
      end

      it "creates an invoice linked to the template", :aggregate_failures do
        expect { post invoices_path(format: :json), params: params, as: :json }
          .to change(Invoice, :count).by(1)
        expect(Invoice.find(response.parsed_body["id"]).invoice_template).to eq(template)
      end

      it "does not create a duplicate for the same template and month" do
        post invoices_path(format: :json), params: params, as: :json
        expect { post invoices_path(format: :json), params: params, as: :json }
          .not_to change(Invoice, :count)
      end
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

      it "accepts and saves a due_date" do
        patch invoice_path(invoice), params: { invoice: { due_date: "2026-02-15" } }
        expect(invoice.reload.due_date).to eq(Date.new(2026, 2, 15))
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

    context "when finalizing invoice" do
      it "assigns number and allocates payment" do
        invoice = create(:invoice, status: :draft, number: nil)
        patch invoice_path(invoice), params: { invoice: { status: "finalized" } }
        expect(invoice.reload).to have_attributes(status: "finalized", number: be_present)
      end
    end
  end
end
