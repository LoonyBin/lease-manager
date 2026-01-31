# frozen_string_literal: true

class ReportsController < ApplicationController
  skip_after_action :verify_pundit_authorization
  before_action { authorize :report }

  def index
    @total_revenue = finalized_invoices.sum(&:total_amount)
    @total_outstanding = policy_scope(Invoice).where.not(status: %i[cancelled draft]).sum(&:outstanding_amount)
    @total_taxes = finalized_line_items.sum("ROUND(amount * tax_rate / 100.0, 2)")
    @total_collected = policy_scope(Payment).sum(:amount)
  end

  def revenue
    @invoices_by_month = group_invoices_by_month
    @invoices_by_property = group_invoices_by_property
  end

  def outstanding
    @outstanding_invoices = policy_scope(Invoice).where.not(status: %i[cancelled draft paid])
                                                 .includes(lease: %i[property tenant])
                                                 .select { |i| i.outstanding_amount.positive? }
                                                 .sort_by(&:date)

    @total_outstanding = @outstanding_invoices.sum(&:outstanding_amount)
  end

  def taxes
    @taxes_by_month = group_taxes_by_month
    @total_taxes = finalized_line_items.sum("amount * tax_rate / 100.0")
  end

  private

  def finalized_invoices
    @finalized_invoices ||= policy_scope(Invoice).where(status: %i[finalized sent paid partially_paid])
                                                 .includes(lease: %i[property tenant])
  end

  def finalized_line_items
    @finalized_line_items ||= LineItem.joins(:invoice)
                                      .where(invoice_id: policy_scope(Invoice).select(:id))
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
    finalized_line_items.joins(invoice: :lease)
                        .group_by { |li| li.invoice.date.beginning_of_month }
                        .transform_values { |items| items.sum { |li| (li.amount * li.tax_rate / 100.0).round(2) } }
                        .sort.reverse.to_h
  end
end
