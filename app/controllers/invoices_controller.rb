# frozen_string_literal: true

class InvoicesController < ApplicationController
  respond_to :html, :json

  def index
    @q = policy_scope(Invoice).ransack(params[:q])
    @q.sorts = ["date desc", "created_at desc", "id desc"] if @q.sorts.empty?
    @invoices = @q.result.with_total_amount.includes(lease: %i[property tenant]).page(params[:page]).per(20)
    respond_ok @invoices
  end

  def show
    @invoice = Invoice.find(params.expect(:id))
    authorize @invoice
    # Line items are the point of a single invoice, but they would multiply the
    # index payload by their row count, so they hang off show alone.
    respond_ok { @invoice.as_json(include: :line_items) }
  end

  def new
    @invoice = build_invoice
    authorize @invoice
    set_form_collections
  end

  def edit
    @invoice = Invoice.find(params.expect(:id))
    authorize @invoice
  end

  def audit
    authorize Invoice, :index?
    detector = MissingInvoiceDetector.new
    @missing_invoices = detector.call
    @leases_without_templates = detector.leases_without_templates
    respond_ok { audit_payload }
  end

  def create
    @invoice = build_invoice
    authorize @invoice
    @invoice.save unless @invoice.persisted?
    set_form_collections unless @invoice.persisted?
    respond_with @invoice
  end

  def update
    @invoice = Invoice.find(params.expect(:id))
    authorize @invoice
    if @invoice.update(invoice_params)
      respond_updated(@invoice) { redirect_to @invoice, notice: t(".success") }
    else
      respond_invalid(@invoice) { render :edit, status: :unprocessable_content }
    end
  end

  private

  # Hand-picked rather than a record dump, like the reports payloads: the audit's
  # answer is an aggregate over leases and templates, so there is no model whose
  # attributes would serialize it. See #187 — "which months are missing invoices?"
  # was previously answerable only by rendering the HTML page and scraping it.
  def audit_payload
    {
      missing_invoices: @missing_invoices.map { |item| missing_invoice_payload(item) },
      leases_without_templates: @leases_without_templates.map { |lease| audit_lease_payload(lease) }
    }
  end

  # expected_amount is null when the template's amount expression could not be
  # evaluated for that month (InvoiceTemplates::EvaluationError). The month is
  # still genuinely missing; the figure is simply not knowable. A consumer must
  # not read null as zero — that is the one ambiguity this payload has to carry.
  def missing_invoice_payload(item)
    {
      date: item.date,
      lease_id: item.lease.id,
      invoice_template_id: item.template.id,
      invoice_template_name: item.template.name,
      property: { id: item.property.id, name: item.property.name },
      tenant: { id: item.tenant.id, name: item.tenant.name },
      expected_amount: item.expected_amount
    }
  end

  def audit_lease_payload(lease)
    {
      id: lease.id,
      property: { id: lease.property.id, name: lease.property.name },
      tenant: { id: lease.tenant.id, name: lease.tenant.name }
    }
  end

  # Prefills rental invoices from an invoice template when a lease and date
  # are given without explicit line items (invoice form and audit page).
  def build_invoice
    invoice = Invoice.new(invoice_params || {})
    return invoice unless prefill?(invoice)

    template = prefill_template_for(invoice)
    return invoice if template.nil?

    generated = TemplateInvoiceGenerator.new(template, invoice.date).call
    return invoice if generated.nil?

    # Callers may pin due_date/status; never mutate a deduped existing invoice.
    generated.assign_attributes(invoice.attributes.slice("due_date", "status").compact) if generated.new_record?
    generated
  rescue InvoiceTemplates::EvaluationError
    # An expression that fails for this month falls back to a blank form.
    invoice
  end

  def prefill?(invoice)
    invoice.lease_id? && invoice.date? && invoice.invoice? && invoice.line_items.empty?
  end

  # The requested template (nil when stale, falling back to a blank form), or
  # the first template lacking an invoice for the month; when every template
  # is invoiced, the first one, so the dedup path returns the existing invoice.
  def prefill_template_for(invoice)
    templates = invoice.lease.invoice_templates.includes(:line_items)
    return templates.find_by(id: invoice.invoice_template_id) if invoice.invoice_template_id.present?

    month = invoice.date.beginning_of_month
    invoiced_ids = invoiced_template_ids(invoice.lease, month)
    templates.detect { |t| invoiced_ids.exclude?(t.id) && t.generates_for?(month) } || templates.first
  end

  # Whole-month range to match the generator's dedup (dates are editable).
  # +covering+ so a template-linked credit note does not mask its template from
  # the prefill picker, keeping this in step with the generator. See #163.
  def invoiced_template_ids(lease, month)
    Invoice.where(lease: lease, date: month..month.end_of_month)
           .where.not(invoice_template_id: nil).covering.pluck(:invoice_template_id)
  end

  def set_form_collections
    @leases = policy_scope(Lease).includes(:property, :tenant) unless @invoice.lease_id?
    @invoice_templates = @invoice.lease&.invoice_templates
  end

  def invoice_params
    params.permit(invoice: [:lease_id, :invoice_template_id, :date, :due_date, :status, :document_type,
                            { line_items_attributes: %i[id name amount tax_rate category _destroy] }])[:invoice]
  end
end
