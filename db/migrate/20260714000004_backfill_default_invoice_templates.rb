# frozen_string_literal: true

class BackfillDefaultInvoiceTemplates < ActiveRecord::Migration[8.1]
  def up
    Lease.find_each do |lease|
      next if lease.invoice_templates.exists?

      template = InvoiceTemplates::DefaultBuilder.new(lease).call
      template.save!
      link_historical_invoices(lease, template)
    end
  end

  def down
    # destroy_all so dependent line items are removed (their FK has no
    # cascade) and invoices.invoice_template_id is nullified.
    InvoiceTemplate.destroy_all
  end

  private

  # Adopt legacy generator output (one rental invoice per month) so the
  # template-based dedup and the audit page see those months as covered.
  def link_historical_invoices(lease, template)
    rental_invoices = Invoice.where(lease_id: lease.id, document_type: :invoice, invoice_template_id: nil)
                             .joins(:line_items).where(line_items: { category: "rent" })
                             .distinct.order(:date, :id)

    rental_invoices.group_by { |invoice| invoice.date.beginning_of_month }.each_value do |invoices|
      invoices.first.update_column(:invoice_template_id, template.id) # rubocop:disable Rails/SkipsModelValidations
    end
  end
end
