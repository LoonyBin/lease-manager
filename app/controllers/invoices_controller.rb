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

    if @invoice.draft?
      ActiveRecord::Base.transaction do
        InvoiceNumberingService.new(@invoice).call
        @invoice.finalized!
      end
      redirect_to @invoice, notice: t(".success")
    else
      redirect_to @invoice, alert: t(".not_draft")
    end
  end
end
