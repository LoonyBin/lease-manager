# frozen_string_literal: true

module PaymentsHelper
  # turbo_confirm text for the Reject button, which now shows for every
  # non-rejected payment. A draft has no ledger footprint, and a refund draws
  # down credits rather than paying invoices, so the warning about what
  # rejection removes differs by state.
  def reject_confirmation_prompt(payment)
    return "Reject this #{payment.refund? ? 'refund' : 'payment'}?" if payment.draft?
    return "Reject this refund? This removes it from every credit it has drawn from." if payment.refund?

    "Reject this payment? This removes it from every invoice it has paid."
  end
end
