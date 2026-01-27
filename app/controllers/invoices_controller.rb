# frozen_string_literal: true

class InvoicesController < ApplicationController
  def index
    @invoices = Invoice.order(date: :desc)
  end

  def show
    @invoice = Invoice.find(params[:id])
  end

  def finalize
    @invoice = Invoice.find(params[:id])

    return redirect_to @invoice, alert: t(".not_draft") unless @invoice.draft?

    finalize_transaction
    redirect_to @invoice, notice: t(".success")
  end

  private

  def finalize_transaction
    ActiveRecord::Base.transaction do
      InvoiceNumberingService.new(@invoice).call
      @invoice.finalized!
      PaymentService.allocate_excess(@invoice)
    end
  end
end
