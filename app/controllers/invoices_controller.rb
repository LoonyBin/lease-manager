# frozen_string_literal: true

class InvoicesController < ApplicationController
  include InvoiceAuditSerialization

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

  # Prefills rental invoices from an invoice template when a lease and date
  # are given without explicit line items (invoice form and audit page).
  def build_invoice
    invoice = Invoice.new(invoice_params || {})
    return invoice unless prefill?(invoice)

    # No result (stale template, failing expression, nothing to bill) falls
    # back to a blank form.
    generated = InvoicePrefill.new(lease: invoice.lease, date: invoice.date,
                                   invoice_template_id: invoice.invoice_template_id).call.invoice
    return invoice if generated.nil?

    # Callers may pin due_date/status; never mutate a deduped existing invoice.
    generated.assign_attributes(invoice.attributes.slice("due_date", "status").compact) if generated.new_record?
    generated
  end

  def prefill?(invoice)
    invoice.lease_id? && invoice.date? && invoice.invoice? && invoice.line_items.empty?
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
