# frozen_string_literal: true

# Builds an unsaved draft invoice for an invoice template and month.
# Returns the existing invoice when the template already generated one for
# that month, and nil when the month is outside the template's effective
# window, rent was already billed manually for the month, or no line item
# evaluates to a non-zero amount.
class TemplateInvoiceGenerator
  ROUND_OFF_CATEGORY = "rounding"
  ROUND_OFF_NAME = "Round Off"
  RENT_CATEGORY = "rent"

  # +find_existing: false+ skips the dedup lookups and always builds a fresh
  # invoice (used by form previews).
  def initialize(template, date, find_existing: true)
    @template = template
    @lease = template.lease
    @date = date&.to_date&.beginning_of_month
    @find_existing = find_existing
  end

  def call
    return nil if @date.nil?

    if find_existing?
      existing = Invoice.find_by(invoice_template: @template, date: month_range)
      return existing if existing
      return nil if rent_billed_manually?
    end

    generate if @template.generates_for?(@date)
  end

  private

  def generate
    invoice = build_invoice
    build_line_items(invoice)
    return nil if invoice.line_items.empty?

    append_round_off_line(invoice)
    invoice
  end

  def find_existing?
    @find_existing && @template.persisted?
  end

  def month_range
    @date..@date.end_of_month
  end

  # Legacy-generator parity: a manually created invoice (no template link)
  # that bills rent suppresses rent-billing templates for the month, so the
  # batch run cannot double-bill rent. Templates without a rent line still
  # generate; cancelled invoices and credit notes do not count.
  def rent_billed_manually?
    bills_rent? && manual_rent_invoice_exists?
  end

  def bills_rent?
    @template.line_items.any? do |line|
      line.category == RENT_CATEGORY && !line.marked_for_destruction?
    end
  end

  def manual_rent_invoice_exists?
    Invoice.where(lease: @lease, invoice_template_id: nil, date: month_range, document_type: :invoice)
           .where.not(status: :cancelled)
           .joins(:line_items).exists?(line_items: { category: RENT_CATEGORY })
  end

  def build_invoice
    Invoice.new(
      lease: @lease,
      invoice_template: @template,
      date: @date,
      due_date: @date + @template.payment_due_in,
      status: :draft
    )
  end

  def variables
    @variables ||= InvoiceTemplates::Context.new(@lease, @date).variables
  end

  def build_line_items(invoice)
    renderer = InvoiceTemplates::TextRenderer.new(variables)
    evaluator = InvoiceTemplates::AmountEvaluator.new(variables)

    @template.line_items.each do |line|
      next if line.marked_for_destruction?

      amount = evaluator.evaluate(line.amount_expression)
      next if amount.zero?

      invoice.line_items.build(name: renderer.render(line.name), amount: amount,
                               tax_rate: line.tax_rate, category: line.category)
    end
  end

  # Invoice totals are rounded to whole currency units by appending the
  # difference as an untaxed line item (totals are derived from line items).
  def append_round_off_line(invoice)
    total = invoice.total_amount
    round_off = (total.round - total).round(InvoiceTemplates::AmountEvaluator::AMOUNT_DECIMAL_PLACES)
    return if round_off.zero?

    invoice.line_items.build(name: ROUND_OFF_NAME, amount: round_off, tax_rate: 0, category: ROUND_OFF_CATEGORY)
  end
end
