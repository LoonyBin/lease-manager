# frozen_string_literal: true

# Builds the JSON payloads for ReportsController's four actions from the
# instance variables the HTML templates already assign. Keeping this out of the
# controller keeps both classes within their RuboCop metrics budgets, and money
# is serialized deliberately (see +money+) rather than as raw BigDecimal.
module ReportSerialization
  extend ActiveSupport::Concern

  private

  # Money as an unpadded decimal string, rounded half-up to at most 2 places to
  # match the figure the UI shows (number_to_currency / BigDecimal#round), and
  # never via Float (format("%.2f", ...) rounds half-to-even and disagrees).
  # nil stays nil so it serializes to JSON null.
  def money(value)
    value && value.to_d.round(2).to_s("F")
  end

  def index_payload
    { total_revenue: money(@total_revenue),
      total_outstanding: money(@total_outstanding),
      total_taxes: money(@total_taxes),
      total_collected: money(@total_collected),
      revenue_by_month: @revenue_by_month.transform_values { |amount| money(amount) },
      payments_by_month: @payments_by_month.transform_values { |amount| money(amount) },
      occupancy_stats: @occupancy_stats,
      invoice_status_distribution: policy_scope(Invoice).group(:status).count }
  end

  def revenue_payload
    { by_month: month_keyed(@invoices_by_month),
      by_property: @invoices_by_property.map do |property, amount|
        { property_id: property.id, property: property.name, amount: money(amount) }
      end }
  end

  def outstanding_payload
    { total_outstanding: money(@total_outstanding),
      invoices: @outstanding_invoices.map { |invoice| outstanding_invoice_json(invoice) } }
  end

  def outstanding_invoice_json(invoice)
    { id: invoice.id, number: invoice.number, date: invoice.date, due_date: invoice.due_date,
      outstanding_amount: money(invoice.outstanding_amount),
      lease: invoice.lease.to_s, property: invoice.lease.property.name, tenant: invoice.lease.tenant.name }
  end

  def taxes_payload
    { total_taxes: money(@total_taxes), by_month: month_keyed(@taxes_by_month) }
  end

  # Date-keyed aggregate -> "%b %Y"-keyed decimal strings, matching the month
  # labels the index charts already use. Key order is incidental, not a contract.
  def month_keyed(by_date)
    by_date.transform_keys { |date| date.strftime("%b %Y") }
           .transform_values { |amount| money(amount) }
  end
end
