# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Invoice previews" do
  let(:lease) { create(:lease) }
  let(:date) { lease.start_date.next_month.beginning_of_month }
  let(:payload) { response.parsed_body }
  let(:money) { /\A-?\d+(\.\d{1,2})?\z/ }

  # Eager so the lease's after_create side effects stay out of count blocks.
  before { lease }

  def written_records
    versions = PaperTrail::Version.where(item_type: %w[Invoice LineItem Entry]).count
    [Invoice.count, LineItem.count, Entry.count, versions]
  end

  def preview(headers: {}, target: lease, **params)
    get lease_invoice_preview_path(target, format: :json), params: { date: date.iso8601 }.merge(params),
                                                           headers: headers
  end

  context "when signed in as admin" do
    before { sign_in_admin }

    it "returns an unsaved draft", :aggregate_failures do
      preview
      expect(response).to have_http_status(:ok)
      expect(payload).to include("persisted" => false, "reason" => nil)
      expect(payload["invoice"]).to include("id" => nil, "lease_id" => lease.id, "status" => "draft")
      expect(payload["invoice_template"]).to include("id" => lease.invoice_templates.order(:id).first.id)
    end

    it "persists nothing for a draft" do
      expect { preview }.not_to(change { written_records })
    end

    it "persists nothing when an amount expression fails", :aggregate_failures do
      lease.invoice_templates.first.line_items.first.update_column(:amount_expression, "no_such_variable") # rubocop:disable Rails/SkipsModelValidations
      expect { preview }.not_to(change { written_records })
      expect(payload).to include("reason" => "evaluation_error")
    end

    it "persists nothing when the lease has no templates" do
      lease.invoice_templates.destroy_all
      expect { preview }.not_to(change { written_records })
    end

    it "reports a negative Round Off line as a decimal string", :aggregate_failures do
      lease.invoice_templates.first.line_items.first.update!(amount_expression: "1000.49", tax_rate: 0)
      preview
      round_off = payload["invoice"]["line_items"].find { |l| l["category"] == "rounding" }
      expect(round_off).to include("amount" => "-0.49")
      expect(round_off.values_at("amount", "tax_rate", "tax_amount", "total")).to all(be_a(String).and(match(money)))
    end

    it "reports money fields as decimal strings" do
      preview
      invoice = payload["invoice"]
      amounts = [invoice["total_amount"], invoice["balance"]] +
                invoice["line_items"].flat_map { |l| l.values_at("amount", "tax_rate", "tax_amount", "total") }
      expect(amounts).to all(be_a(String).and(match(money)))
    end

    it "prints a nil tax rate as a decimal string" do
      lease.invoice_templates.first.line_items.first.update!(tax_rate: nil)
      preview
      expect(payload["invoice"]["line_items"].pluck("tax_amount")).to all(match(money))
    end

    it "does not treat a template-linked credit note as existing", :aggregate_failures do
      create(:invoice, :credit_note, lease: lease, invoice_template: lease.invoice_templates.first, date: date)
      preview
      expect(payload["persisted"]).to be(false)
      expect(payload["invoice"]).to be_present
    end

    it "explains an empty answer when the lease has no templates", :aggregate_failures do
      lease.invoice_templates.destroy_all
      preview
      expect(response).to have_http_status(:ok)
      expect(payload).to include("persisted" => false, "invoice" => nil, "reason" => "no_template")
    end

    it "reports a template id from another lease as template_not_found" do
      preview(invoice_template_id: create(:lease).invoice_templates.first.id)
      expect(payload).to include("invoice" => nil, "reason" => "template_not_found")
    end

    it "persists nothing for template_not_found" do
      foreign_id = create(:lease).invoice_templates.first.id
      expect { preview(invoice_template_id: foreign_id) }.not_to(change { written_records })
    end

    it "reports a month outside the template window as not_generated" do
      preview(date: (lease.start_date - 2.years).iso8601)
      expect(payload).to include("invoice" => nil, "reason" => "not_generated")
    end

    it "persists nothing for not_generated" do
      expect { preview(date: (lease.start_date - 2.years).iso8601) }.not_to(change { written_records })
    end

    it "reports a failing amount expression as evaluation_error" do
      allow(TemplateInvoiceGenerator).to receive(:new).and_raise(InvoiceTemplates::EvaluationError, "boom")
      preview
      expect(payload).to include("invoice" => nil, "reason" => "evaluation_error")
    end

    it "rejects a missing date", :aggregate_failures do
      get lease_invoice_preview_path(lease, format: :json)
      expect(response).to have_http_status(:unprocessable_content)
      expect(payload["errors"]).to have_key("date")
    end

    it "rejects an unparseable date" do
      preview(date: "not-a-date")
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "rejects a hash-shaped date" do
      preview(date: { x: "1" })
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "answers 406 for HTML" do
      get lease_invoice_preview_path(lease), params: { date: date.iso8601 }
      expect(response).to have_http_status(:not_acceptable)
    end
  end

  describe "saved versus draft" do
    before do
      sign_in_admin
      lease.invoice_templates.each { |t| TemplateInvoiceGenerator.new(t, date).call.save! }
    end

    def first_template_invoice
      lease.invoices.find_by!(invoice_template: lease.invoice_templates.order(:id).first)
    end

    it "returns the saved invoice even when its status is draft", :aggregate_failures do
      preview
      expect(payload).to include("persisted" => true)
      expect(payload["invoice"]).to include("status" => "draft", "id" => first_template_invoice.id)
    end

    it "persists nothing for a saved invoice" do
      expect { preview }.not_to(change { written_records })
    end

    it "reports money fields on a saved invoice as decimal strings" do
      preview
      invoice = payload["invoice"]
      amounts = [invoice["total_amount"], invoice["balance"]] +
                invoice["line_items"].flat_map { |l| l.values_at("amount", "tax_rate", "tax_amount", "total") }
      expect(amounts).to all(be_a(String).and(match(money)))
    end

    it "prints a nil tax rate on a saved invoice as a decimal string" do
      first_template_invoice.line_items.update_all(tax_rate: nil) # rubocop:disable Rails/SkipsModelValidations
      preview
      expect(payload["invoice"]["line_items"].pluck("tax_amount")).to all(match(money))
    end

    it "returns a cancelled invoice as persisted", :aggregate_failures do
      lease.invoices.update_all(status: Invoice.statuses[:cancelled]) # rubocop:disable Rails/SkipsModelValidations
      preview
      expect(payload).to include("persisted" => true)
      expect(payload["invoice"]["status"]).to eq("cancelled")
    end
  end

  describe "with an API token" do
    let(:user) { create(:user, :admin) }

    def token_header(*permissions)
      token = create(:api_token, :custom, user: user, permissions: permissions)
      { "Authorization" => "Bearer #{token.plaintext_token}" }
    end

    it "serves the draft with only the invoice_previews#show grant", :aggregate_failures do
      preview(headers: token_header("invoice_previews#show"))
      expect(response).to have_http_status(:ok)
      expect(payload["persisted"]).to be(false)
    end

    it "is refused without the grant" do
      preview(headers: token_header("invoices#index"))
      expect(response).to have_http_status(:forbidden)
    end

    it "is refused for a bad token" do
      preview(headers: { "Authorization" => "Bearer lmt_wrong" })
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "scoping" do
    let(:user) { create(:user) }

    before do
      sign_in_as(user)
      allow(InvoicePrefill).to receive(:new).and_call_original
    end

    it "gives the owner of the lease a 200" do
      create(:user_association, user: user, associable: lease.property.owner)
      preview
      expect(response).to have_http_status(:ok)
    end

    it "gives the tenant of the lease a 403 and generates nothing", :aggregate_failures do
      create(:user_association, user: user, associable: lease.tenant)
      preview
      expect(response).to have_http_status(:forbidden)
      expect(InvoicePrefill).not_to have_received(:new)
    end

    it "gives the owner of another lease a 404 and generates nothing", :aggregate_failures do
      create(:user_association, user: user, associable: create(:lease).property.owner)
      preview
      expect(response).to have_http_status(:not_found)
      expect(InvoicePrefill).not_to have_received(:new)
    end

    it "gives an unrelated user a 404" do
      preview
      expect(response).to have_http_status(:not_found)
    end
  end
end
