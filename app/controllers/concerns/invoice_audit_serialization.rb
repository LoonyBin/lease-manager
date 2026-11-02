# frozen_string_literal: true

# Builds the JSON payload for InvoicesController#audit from the instance
# variables the HTML template already assigns. Kept out of the controller for
# the same reason as ReportSerialization — it keeps both classes within their
# RuboCop metrics budgets.
#
# Like the reports, the audit serializes an explicit, hand-picked payload rather
# than a record's attributes: its answer is an aggregate over leases and
# templates, so there is no model to dump. See #187.
module InvoiceAuditSerialization
  extend ActiveSupport::Concern

  private

  def audit_payload
    {
      missing_invoices: @missing_invoices.map { |item| missing_invoice_payload(item) },
      leases_without_templates: @leases_without_templates.map { |lease| audit_lease_payload(lease) }
    }
  end

  # expected_amount is null when the template's amount expression could not be
  # evaluated for that month (InvoiceTemplates::EvaluationError). The month is
  # still genuinely missing; the figure is simply not knowable. A consumer must
  # not read null as zero — that is the one ambiguity this payload has to carry.
  def missing_invoice_payload(item)
    {
      date: item.date,
      lease_id: item.lease.id,
      invoice_template_id: item.template.id,
      invoice_template_name: item.template.name,
      property: { id: item.property.id, name: item.property.name },
      tenant: { id: item.tenant.id, name: item.tenant.name },
      expected_amount: item.expected_amount
    }
  end

  def audit_lease_payload(lease)
    {
      id: lease.id,
      property: { id: lease.property.id, name: lease.property.name },
      tenant: { id: lease.tenant.id, name: lease.tenant.name }
    }
  end
end
