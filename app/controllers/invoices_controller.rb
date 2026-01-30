# frozen_string_literal: true

class InvoicesController < ApplicationController
  def index
    @invoices = policy_scope(Invoice).order(date: :desc)
  end

  def show
    @invoice = Invoice.find(params[:id])
    authorize @invoice
  end

  def new
    if params[:lease_id] && params[:date]
      @lease = Lease.find(params[:lease_id])
      date = Date.parse(params[:date])
      @invoice = ::InvoiceGenerator.new(@lease, date).call
    else
      @invoice = Invoice.new
    end
    authorize @invoice
  end

  def edit
    @invoice = Invoice.find(params[:id])
    authorize @invoice
  end

  def create
    @invoice = Invoice.new(invoice_params)
    authorize @invoice

    if @invoice.save
      redirect_to @invoice, notice: t(".success")
    else
      render :new, status: :unprocessable_content
    end
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

  def invoice_params
    params.expect(invoice: [:lease_id, :date, :status,
                            { line_items_attributes: [%i[id name amount tax_rate category _destroy]] }])
  end
end
