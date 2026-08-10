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

  # turbo_confirm text for the Delete button. Deliberately worded around "never
  # existed / removes it from the books entirely" so it reads as disjoint from
  # Reject's "removes it from every invoice it has paid" — the two destructive
  # controls sit side by side and must not be mistaken for each other (#196).
  # Destroying the payment purges its Active Storage blob, so warn when one is
  # attached: PaperTrail keeps the attributes but not the scan.
  def delete_confirmation_prompt(payment)
    base = "Delete this #{payment.refund? ? 'refund' : 'payment'}? " \
           "This removes it from the books entirely, as if it never existed."
    return base unless payment.attachment.attached?

    "#{base} The attached file will also be permanently deleted."
  end
end
