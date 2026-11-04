# frozen_string_literal: true

# A read-only answer to "what invoice would the form prefill for this lease and
# month?". Saves nothing, so it sits on GET and a read-only token can use it.
class InvoicePreviewsController < ApplicationController
  def show
    lease = policy_scope(Lease).find(params.expect(:lease_id))
    requested = Invoice.new(lease: lease, **preview_params)
    authorize requested, :preview?
    return render_missing_date if requested.date.nil?

    respond_to { |format| format.json { render json: preview_payload(prefill_for(requested)) } }
  end

  private

  def preview_params
    params.permit(:date, :invoice_template_id).to_h.symbolize_keys
  end

  def prefill_for(requested)
    InvoicePrefill.new(lease: requested.lease, date: requested.date,
                       invoice_template_id: requested.invoice_template_id).call
  end

  def render_missing_date
    respond_to do |format|
      format.json do
        render json: { errors: { date: [t("invoice_previews.show.date_invalid")] } }, status: :unprocessable_content
      end
    end
  end

  # +persisted+, not +invoice.status+, tells a saved invoice from an unsaved
  # draft: a saved invoice can itself have the status "draft".
  def preview_payload(result)
    invoice = result.invoice
    {
      persisted: invoice&.persisted? || false,
      reason: result.reason,
      invoice_template: invoice&.invoice_template&.slice(:id, :name),
      invoice: invoice&.as_json(include: :line_items)
    }
  end
end
