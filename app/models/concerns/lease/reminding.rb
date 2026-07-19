# frozen_string_literal: true

class Lease
  # The lease's reminder policy: the ordered escalation steps its unsettled
  # invoices are chased with, and the per-lease opt-out.
  module Reminding
    extend ActiveSupport::Concern

    included do
      has_many :reminder_steps, -> { order(:position, :id) }, inverse_of: :lease, dependent: :destroy

      scope :reminding, -> { where(reminders_enabled: true) }

      after_create :create_default_reminder_steps
    end

    # The lease-side eligibility the `not_archived`/`reminding` scopes express,
    # as a predicate — so a notification queued before the lease was archived
    # or opted out is re-checked against the same rule at dispatch time.
    def reminding?
      reminders_enabled? && !archived?
    end

    private

    # Wrapped in a savepoint so a step that fails validation part-way through
    # cannot leave the lease with a half-built policy; the rescue sits outside
    # the transaction, leaving lease creation itself untouched.
    def create_default_reminder_steps
      ReminderStep.transaction(requires_new: true) do
        if renewed_from.present?
          copy_reminder_steps_from(renewed_from)
        else
          Reminders::DefaultPolicyBuilder.new(self).call.each(&:save!)
        end
      end
    rescue ActiveRecord::RecordInvalid => e
      # A lease without reminder steps simply never chases; never fail lease
      # creation over its default policy (the lease page surfaces the gap).
      Rails.logger.error("Default reminder step creation failed for lease #{id}: #{e.message}")
    end
  end
end
