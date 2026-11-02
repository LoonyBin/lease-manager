# frozen_string_literal: true

# Answers "which invoice would the form prefill for this lease and month?".
# Shared by the invoice form and the JSON preview so both pick the same
# template. Never saves: the invoice is either an unsaved draft or an existing
# one the template already generated for the month.
class InvoicePrefill
  Result = Struct.new(:invoice, :reason)

  def initialize(lease:, date:, invoice_template_id: nil)
    @lease = lease
    @date = date
    @invoice_template_id = invoice_template_id
  end

  # reason is nil when an invoice was found, otherwise one of :no_template,
  # :template_not_found, :not_generated, :evaluation_error.
  def call
    return Result.new(nil, :no_template) if templates.empty?

    template = template_for
    return Result.new(nil, :template_not_found) if template.nil?

    invoice = TemplateInvoiceGenerator.new(template, @date).call
    invoice ? Result.new(invoice, nil) : Result.new(nil, :not_generated)
  rescue InvoiceTemplates::EvaluationError
    Result.new(nil, :evaluation_error)
  end

  private

  # Ordered by id: without an ORDER BY, "first" depends on physical row order,
  # which can shift when a template is updated.
  def templates
    @templates ||= @lease.invoice_templates.includes(:line_items).order(:id).to_a
  end

  # The requested template (nil when stale), or the first template lacking an
  # invoice for the month; when every template is invoiced, the first one, so
  # the dedup path returns the existing invoice.
  def template_for
    return templates.find { |t| t.id == @invoice_template_id.to_i } if @invoice_template_id.present?

    month = @date.beginning_of_month
    invoiced_ids = invoiced_template_ids(month)
    templates.detect { |t| invoiced_ids.exclude?(t.id) && t.generates_for?(month) } || templates.first
  end

  # Whole-month range to match the generator's dedup (dates are editable).
  # +covering+ so a template-linked credit note does not mask its template from
  # the prefill picker, keeping this in step with the generator. See #163.
  def invoiced_template_ids(month)
    Invoice.where(lease: @lease, date: month..month.end_of_month)
           .where.not(invoice_template_id: nil).covering.pluck(:invoice_template_id)
  end
end
