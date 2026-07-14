# frozen_string_literal: true

require "rails_helper"

RSpec.describe "InvoiceTemplates" do
  before { sign_in_admin }

  let(:lease) { create(:lease) }
  let(:template) { lease.invoice_templates.first }

  let(:valid_params) do
    { invoice_template: { name: "Maintenance", payment_due_in: "P9D",
                          line_items_attributes: { "0" => { name: "Fixed maintenance charge",
                                                            amount_expression: "2500",
                                                            tax_rate: 0, category: "maintenance" } } } }
  end

  describe "GET /leases/:lease_id/invoice_templates/new" do
    it "returns http success" do
      get new_lease_invoice_template_path(lease)
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /leases/:lease_id/invoice_templates" do
    it "creates a template and redirects to the lease", :aggregate_failures do
      expect { post lease_invoice_templates_path(lease), params: valid_params }
        .to change(lease.invoice_templates, :count).by(1)
      expect(response).to redirect_to(lease_path(lease))
      expect(lease.invoice_templates.last.line_items.first.amount_expression).to eq("2500")
    end

    context "with an unknown variable in the expression" do
      let(:invalid_params) do
        { invoice_template: { name: "Broken", payment_due_in: "P9D",
                              line_items_attributes: { "0" => { name: "Broken", amount_expression: "rennt",
                                                                tax_rate: 0, category: "other" } } } }
      end

      it "rejects the template", :aggregate_failures do
        expect { post lease_invoice_templates_path(lease), params: invalid_params }
          .not_to change(lease.invoice_templates, :count)
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("references unknown variables: rennt")
      end
    end
  end

  describe "GET /leases/:lease_id/invoice_templates/:id/edit" do
    it "returns http success" do
      get edit_lease_invoice_template_path(lease, template)
      expect(response).to have_http_status(:success)
    end
  end

  describe "PATCH /leases/:lease_id/invoice_templates/:id" do
    it "updates the template", :aggregate_failures do
      patch lease_invoice_template_path(lease, template),
            params: { invoice_template: { name: "Rent (custom)" } }
      expect(response).to redirect_to(lease_path(lease))
      expect(template.reload.name).to eq("Rent (custom)")
    end

    it "updates nested line items" do
      patch lease_invoice_template_path(lease, template),
            params: { invoice_template: { line_items_attributes: { "0" => {
              id: template.line_items.first.id, amount_expression: "rent * f"
            } } } }
      expect(template.line_items.first.reload.amount_expression).to eq("rent * f")
    end

    it "rejects removing every line item" do
      line_item = template.line_items.first
      template.line_items.where.not(id: line_item.id).destroy_all
      patch lease_invoice_template_path(lease, template),
            params: { invoice_template: { line_items_attributes: { "0" => { id: line_item.id, _destroy: "1" } } } }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "DELETE /leases/:lease_id/invoice_templates/:id" do
    it "destroys the template and keeps its invoices", :aggregate_failures do
      invoice = TemplateInvoiceGenerator.new(template, lease.start_date).call.tap(&:save!)

      expect { delete lease_invoice_template_path(lease, template) }
        .to change(InvoiceTemplate, :count).by(-1)
      expect(response).to redirect_to(lease_path(lease))
      expect(invoice.reload.invoice_template_id).to be_nil
    end
  end

  describe "POST /leases/:lease_id/invoice_templates/preview" do
    it "renders the evaluated invoice for the requested month", :aggregate_failures do
      post preview_lease_invoice_templates_path(lease),
           params: valid_params.merge(preview_month: lease.start_date.iso8601)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Fixed maintenance charge")
      expect(response.body).to include("2,500")
    end

    it "shows validation errors for unknown variables" do
      params = valid_params.deep_merge(invoice_template: {
                                         line_items_attributes: { "0" => { amount_expression: "rennt" } }
                                       })
      post preview_lease_invoice_templates_path(lease), params: params.merge(preview_month: lease.start_date.iso8601)
      expect(response.body).to include("references unknown variables: rennt")
    end

    it "reports months outside the generation window" do
      post preview_lease_invoice_templates_path(lease),
           params: valid_params.merge(preview_month: (lease.start_date - 1.year).iso8601)
      expect(response.body).to include("outside this template")
    end

    it "previews a persisted template via PATCH", :aggregate_failures do
      patch preview_lease_invoice_templates_path(lease),
            params: { id: template.id, preview_month: lease.start_date.iso8601,
                      invoice_template: { name: template.name, payment_due_in: "P9D" } }
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Rent for #{lease.start_date.strftime('%B %Y')}")
    end
  end

  context "when signed in as an unrelated user" do
    it "denies template creation" do
      sign_in_user
      post lease_invoice_templates_path(lease), params: valid_params
      expect(response).to redirect_to(root_path)
    end
  end
end
