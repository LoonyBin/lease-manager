# frozen_string_literal: true

class ReportsController < ApplicationController
  def index
    @total_revenue = finalized_invoices.sum(&:total_amount)
    @total_outstanding = Invoice.where.not(status: %i[cancelled draft]).sum(&:outstanding_amount)
    @total_taxes = tax_line_items.sum(:amount)
    @total_collected = Payment.sum(:amount)
  end

  def revenue
    @invoices_by_month = group_invoices_by_month
    @invoices_by_property = group_invoices_by_property
  end

  def outstanding
    @outstanding_invoices = Invoice.where.not(status: %i[cancelled draft paid])
                                   .includes(lease: %i[property tenant])
                                   .select { |i| i.outstanding_amount.positive? }
                                   .sort_by(&:date)

    @total_outstanding = @outstanding_invoices.sum(&:outstanding_amount)
  end

  def taxes
    @taxes_by_month = group_taxes_by_month
    @total_taxes = tax_line_items.sum(:amount)
  end

  private

  def finalized_invoices
    @finalized_invoices ||= Invoice.where(status: %i[finalized sent paid partially_paid])
                                   .includes(lease: %i[property tenant])
  end

  def tax_line_items
    @tax_line_items ||= LineItem.where(category: "tax")
                                .joins(:invoice)
                                .where(invoices: { status: %i[finalized sent paid partially_paid] })
  end

  def group_invoices_by_month
    finalized_invoices.group_by { |i| i.date.beginning_of_month }
                      .transform_values { |invoices| invoices.sum(&:total_amount) }
                      .sort.reverse.to_h
  end

  def group_invoices_by_property
    finalized_invoices.group_by { |i| i.lease.property }
                      .transform_values { |invoices| invoices.sum(&:total_amount) }
  end

  def group_taxes_by_month
    tax_line_items.joins(invoice: :lease)
                  .group_by { |li| li.invoice.date.beginning_of_month }
                  .transform_values { |items| items.sum(&:amount) }
                  .sort.reverse.to_h
  end
end
