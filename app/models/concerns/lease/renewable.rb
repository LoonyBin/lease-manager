# frozen_string_literal: true

class Lease
  module Renewable
    extend ActiveSupport::Concern

    # Key of the advisory lock that serialises the renewal checks against each
    # other. "Leas" in hexadecimal, so it is unlikely to collide with another
    # advisory lock in the same database.
    RENEWAL_LINK_LOCK_KEY = 0x4C656173

    included do
      belongs_to :renewed_from, class_name: "Lease", optional: true, inverse_of: :renewal
      has_one :renewal, class_name: "Lease", foreign_key: :renewed_from_id, dependent: :nullify,
                        inverse_of: :renewed_from

      after_create :terminate_renewed_from_lease, if: :renewed_from_id?

      validate :renewed_from_is_renewable
    end

    class_methods do
      def build_renewal(old_lease)
        new(renewal_attributes_from(old_lease).merge(renewed_from: old_lease))
      end

      def renewal_attributes_from(old_lease)
        new_start = old_lease.end_date + 1.day
        old_lease.slice(:property_id, :tenant_id, :duration_months, :security_deposit_value, :security_deposit_type,
                        :enhancement_period_months, :tax_name, :tax_rate,
                        :property_schedule)
                 .merge(start_date: new_start, rent_amount: old_lease.current_rent_at(new_start),
                        enhancement_type: :inherit, enhancement_amount: nil)
      end
    end

    private

    # A lease may only renew a lease of the same owner, and the chain it
    # creates must not loop: an inheriting lease follows its predecessor, so a
    # loop makes rent calculation recurse forever. One wording covers every
    # case, so the message never reveals whether a lease the user is not
    # allowed to see exists.
    def renewed_from_is_renewable
      return unless renewed_from_id.present? || renewed_from.present?
      return unless new_record? || will_save_change_to_renewed_from_id? || will_save_change_to_property_id?

      with_renewal_link_lock do
        errors.add(:renewed_from, "is not a lease that can be renewed") unless renewable_source?
      end
    end

    # The check and the write that follows it have to be one step: two
    # concurrent updates can each pass the check before the other writes, and
    # together close a cycle between them. A transaction-scoped advisory lock,
    # taken before the chain is read and released when the save's transaction
    # ends, makes the second update wait for the first, read the link the
    # first committed, and refuse it.
    def with_renewal_link_lock
      # A validation outside a transaction (a `valid?` call) has no write to
      # protect, so it skips the lock.
      return yield unless Lease.connection.transaction_open?

      Lease.connection.execute("SELECT pg_advisory_xact_lock(#{RENEWAL_LINK_LOCK_KEY})")
      yield
    end

    def renewable_source?
      return false if renewed_from.blank?
      return false unless same_owner?

      !renewal_chain_loops?
    end

    def same_owner?
      return true if property.blank?

      renewed_from.property&.owner_id == property.owner_id
    end

    # Walks the renewal chain upwards. A chain that reaches this lease, or that
    # visits the same lease twice, is a loop.
    def renewal_chain_loops?
      visited = Set.new
      current_id = renewed_from_id

      while current_id.present?
        return true if visited.include?(current_id)
        return true if persisted? && current_id == id

        visited << current_id
        current_id = Lease.where(id: current_id).pick(:renewed_from_id)
      end

      false
    end

    def terminate_renewed_from_lease
      renewed_from.update!(terminated_on: start_date - 1.day)
    end

    # Renewals inherit the previous lease's reminder policy, including any
    # escalation routing the admin set up by hand.
    def copy_reminder_steps_from(old_lease)
      # Queried fresh rather than through the association, so a caller that
      # already touched +old_lease.reminder_steps+ cannot hand us a stale
      # (or empty) cache.
      ReminderStep.where(lease_id: old_lease.id).order(:position, :id).find_each do |step|
        reminder_steps.create!(
          step.slice(:position, :offset_days, :repeat_every_days, :subject, :body, :to_emails)
        )
      end
    end

    # Renewals inherit the previous lease's templates instead of the default
    # one; generation windows stay nil so they follow the new lease dates.
    def copy_invoice_templates_from(old_lease)
      old_lease.invoice_templates.includes(:line_items).find_each do |template|
        copy = invoice_templates.build(name: template.name, payment_due_in: template.payment_due_in)
        template.line_items.each do |line|
          copy.line_items.build(line.slice(:name, :amount_expression, :tax_rate, :category, :position))
        end
        copy.save!
      end
    end
  end
end
