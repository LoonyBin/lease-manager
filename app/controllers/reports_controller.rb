# frozen_string_literal: true

class ReportsController < ApplicationController
  include ReportSerialization

  skip_after_action :verify_pundit_authorization
  before_action { authorize :report }

  def index
    set_summary_stats
    set_chart_data
    respond_ok { index_payload }
  end

  def revenue
    @invoices_by_month = group_invoices_by_month
    @invoices_by_property = group_invoices_by_property
    respond_ok { revenue_payload }
  end

  def outstanding
    @outstanding_invoices = policy_scope(Invoice).where.not(status: %i[cancelled draft paid])
                                                 .includes(lease: %i[property tenant])
                                                 .select { |i| i.outstanding_amount.positive? }
                                                 .sort_by(&:date)

    @total_outstanding = @outstanding_invoices.sum(&:outstanding_amount)
    respond_ok { outstanding_payload }
  end

  def taxes
    @taxes_by_month = group_taxes_by_month
    # Round each line's tax before summing, matching set_summary_stats and
    # group_taxes_by_month, so total_taxes agrees across every report endpoint.
    @total_taxes = finalized_line_items.sum("ROUND(amount * tax_rate / 100.0, 2)")
    respond_ok { taxes_payload }
  end

  private

  def set_summary_stats
    @total_revenue = finalized_invoices.to_a.sum(&:total_amount)
    @total_outstanding = policy_scope(Invoice).where.not(status: %i[cancelled draft]).sum(:balance)
    @total_taxes = finalized_line_items.sum("ROUND(amount * tax_rate / 100.0, 2)")
    @total_collected = policy_scope(Payment).sum(:amount)
  end

  def set_chart_data
    @revenue_by_month = revenue_by_month_data
    @payments_by_month = policy_scope(Payment).group_by_month(:date, last: 12, format: "%b %Y").sum(:amount)
    @occupancy_stats = calculate_occupancy_stats
    @invoice_status_distribution = policy_scope(Invoice).group(:status).count.transform_keys(&:titleize)
  end

  def revenue_by_month_data
    finalized_invoices.joins(:line_items)
                      .group_by_month(:date, last: 12, format: "%b %Y")
                      .sum("line_items.amount")
  end

  def calculate_occupancy_stats
    active_leases_count = policy_scope(Lease).to_a.count do |l|
      l.end_date && l.end_date >= Date.current && l.start_date <= Date.current
    end
    total_properties = policy_scope(Property).count

    { "Occupied" => active_leases_count, "Vacant" => [total_properties - active_leases_count, 0].max }
  end

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
