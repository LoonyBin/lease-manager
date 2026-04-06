# frozen_string_literal: true

class InvoicesController < ApplicationController
  respond_to :html, :json

  def index
    @q = policy_scope(Invoice).ransack(params[:q])
    @q.sorts = "date desc" if @q.sorts.empty?
    @invoices = @q.result.includes(lease: %i[property tenant]).page(params[:page]).per(20)
  end

  def show
    @invoice = Invoice.find(params[:id])
    authorize @invoice
  end

  def new
    @invoice = ::InvoiceGenerator.new(Invoice.new(invoice_params)).call
    authorize @invoice
    @leases = policy_scope(Lease).includes(:property, :tenant) unless @invoice.lease_id?
  end

  def edit
    @invoice = Invoice.find(params[:id])
    authorize @invoice
  end

  def audit
    authorize Invoice, :index?
    @missing_invoices = MissingInvoiceDetector.new.call
  end

  def create
    @invoice = ::InvoiceGenerator.new(Invoice.new(invoice_params)).call
    authorize @invoice
    @invoice.save unless @invoice.persisted?
    respond_to_create
  end

  def update
    @invoice = Invoice.find(params[:id])
    authorize @invoice
    if @invoice.update(invoice_params)
      redirect_to @invoice, notice: t(".success")
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def respond_to_create
    respond_to do |format|
      if @invoice.persisted?
        redirect_path = safe_return_to(params[:return_to], fallback: invoice_path(@invoice))
        format.html { redirect_to redirect_path, notice: t("invoices.create.success") }
        format.json { render json: @invoice }
      else
        @leases = policy_scope(Lease).includes(:property, :tenant) unless @invoice.lease_id?
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @invoice.errors, status: :unprocessable_content }
      end
    end
  end

  def invoice_params
    params.permit(invoice: [:lease_id, :date, :status, :document_type,
                            { line_items_attributes: %i[id name amount tax_rate category _destroy] }])[:invoice]
  end
end
