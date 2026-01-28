# frozen_string_literal: true

class InvoicesController < ApplicationController
  def index
    @invoices = Invoice.order(date: :desc)
  end

  def show
    @invoice = Invoice.find(params[:id])
  end

  def generate
    @lease = Lease.find(params[:lease_id])
    date = Date.parse(params[:date])

    ::InvoiceGenerator.new(@lease, date).call
    redirect_to lease_path(@lease), notice: t(".success", month: date.strftime("%B %Y"))
  end

  def finalize
    @invoice = Invoice.find(params[:id])

    return redirect_to @invoice, alert: t(".not_draft") unless @invoice.draft?

    finalize_transaction
    redirect_to @invoice, notice: t(".success")
  end

  def edit
    @invoice = Invoice.find(params[:id])
  end

  def update
    @invoice = Invoice.find(params[:id])
    if @invoice.update(invoice_params)
      redirect_to @invoice, notice: t(".success")
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def invoice_params
    params.require(:invoice).permit(:date, :status, line_items_attributes: %i[id name amount category _destroy])
  end

  def finalize_transaction
    ActiveRecord::Base.transaction do
      InvoiceNumberingService.new(@invoice).call
      @invoice.finalized!
      PaymentService.allocate_excess(@invoice)
    end
  end
end
