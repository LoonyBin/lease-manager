# frozen_string_literal: true

class BatchInvoiceGenerator
  def initialize(date = Date.current)
    @date = date
  end

  def call
    InvoiceTemplate.for_active_leases.includes(:lease, :line_items).find_each do |template|
      generate(template)
    end
  end

  private

  # Expressions are validated at save time, but can still fail at evaluation
  # time (e.g. division by a variable that is zero for this month), and saves
  # can fail on validations or a concurrent-run unique-index race; one broken
  # template must not abort the whole run.
  def generate(template)
    invoice = TemplateInvoiceGenerator.new(template, @date).call
    invoice.save! if invoice&.new_record?
  rescue InvoiceTemplates::EvaluationError, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
    Rails.logger.error("Skipping invoice template #{template.id} (lease #{template.lease_id}): #{e.message}")
  end
end
