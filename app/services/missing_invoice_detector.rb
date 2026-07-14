# frozen_string_literal: true

class MissingInvoiceDetector
  MissingInvoice = Struct.new(:lease, :template, :date, :tenant, :property, :expected_amount)

  def initialize(leases = nil)
    @leases = leases || non_upcoming_leases
  end

  def call
    return [] if @leases.empty?

    @leases.flat_map { |lease| missing_for_lease(lease) }.sort_by(&:date)
  end

  # Leases that cannot generate invoices because all templates were deleted.
  # Generation skips them silently; the audit page surfaces them as warnings.
  def leases_without_templates
    @leases.select { |lease| lease.invoice_templates.empty? }
  end

  private

  def non_upcoming_leases
    upcoming_ids = Lease.by_status("upcoming").select(:id)
    Lease.not_archived.where.not(id: upcoming_ids)
         .includes(:property, :tenant, invoice_templates: :line_items)
  end

  def missing_for_lease(lease)
    lease.invoice_templates.flat_map { |template| missing_for_template(lease, template) }
  end

  def missing_for_template(lease, template)
    expected_months(template).filter_map do |month|
      next if existing_invoice_months.include?([template.id, month])

      missing_invoice_for(lease, template, month)
    end
  end

  def missing_invoice_for(lease, template, month)
    invoice = TemplateInvoiceGenerator.new(template, month).call
    return if invoice.nil? || invoice.persisted?

    build_missing(lease, template, month, invoice.total_amount)
  rescue InvoiceTemplates::EvaluationError
    # The month is still missing even when the expression cannot be
    # evaluated; surface it without an expected amount.
    build_missing(lease, template, month, nil)
  end

  def build_missing(lease, template, month, expected_amount)
    MissingInvoice.new(
      lease: lease,
      template: template,
      date: month,
      tenant: lease.tenant,
      property: lease.property,
      expected_amount: expected_amount
    )
  end

  # Months from the template's effective window start through today (or the
  # window end, whichever is earlier).
  def expected_months(template)
    start_on = template.effective_starts_on
    return [] if start_on.nil?

    end_on = [template.effective_ends_on, Time.zone.today].compact.min
    return [] if end_on < start_on

    month_range(start_on.beginning_of_month, end_on.beginning_of_month)
  end

  def month_range(start_month, end_month)
    months = []
    current = start_month
    while current <= end_month
      months << current
      current = current.next_month
    end
    months
  end

  def existing_invoice_months
    @existing_invoice_months ||=
      Invoice.where(lease: @leases)
             .where.not(invoice_template_id: nil)
             .pluck(:invoice_template_id, :date)
             .to_set { |template_id, date| [template_id, date.beginning_of_month] }
  end
end
