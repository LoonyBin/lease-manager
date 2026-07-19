# frozen_string_literal: true

module Reminders
  # Builds the default escalation ladder for a lease: a near-due nudge, a
  # notice on the due date, then a repeating overdue chase. Recipients are
  # seeded from the addresses already known for the lease's tenant; an admin
  # edits the ladder afterwards to route later steps elsewhere.
  class DefaultPolicyBuilder
    NEAR_DUE_OFFSET_DAYS = -7   # not configurable: default policy shape, editable per lease afterwards
    DUE_OFFSET_DAYS = 0         # not configurable: default policy shape, editable per lease afterwards
    OVERDUE_OFFSET_DAYS = 7     # not configurable: default policy shape, editable per lease afterwards
    OVERDUE_REPEAT_DAYS = 14    # not configurable: default policy shape, editable per lease afterwards

    def initialize(lease)
      @lease = lease
    end

    # Returns the built (unsaved) steps, or an empty array when no recipient
    # address is known — a step without recipients cannot validate, and the
    # lease page surfaces the missing policy for the admin to fill in.
    def call
      return [] if recipients.empty?

      step_definitions.each_with_index.map do |definition, index|
        @lease.reminder_steps.build(definition.merge(position: index + 1, to_emails: recipients))
      end
    end

    def self.recipients_for(lease)
      new(lease).recipients
    end

    def recipients
      @recipients ||= ([@lease.tenant&.email] + tenant_user_emails).compact_blank.map { |e| e.strip.downcase }.uniq
    end

    private

    def tenant_user_emails
      return [] if @lease.tenant.nil?

      @lease.tenant.users.pluck(:email)
    end

    def step_definitions
      [near_due_step, due_step, overdue_step]
    end

    def near_due_step
      { offset_days: NEAR_DUE_OFFSET_DAYS, repeat_every_days: nil,
        subject: "Rent due soon — invoice {invoice_number} for {property_name}", body: near_due_body }
    end

    def due_step
      { offset_days: DUE_OFFSET_DAYS, repeat_every_days: nil,
        subject: "Invoice {invoice_number} is due today", body: due_body }
    end

    def overdue_step
      { offset_days: OVERDUE_OFFSET_DAYS, repeat_every_days: OVERDUE_REPEAT_DAYS,
        subject: "Overdue: invoice {invoice_number} for {property_name}", body: overdue_body }
    end

    def near_due_body
      <<~BODY.strip
        Hello {tenant_name},

        This is a reminder that invoice {invoice_number} for {property_name} is due on {due_date}.
        The outstanding balance is {balance_due}.

        You can view the invoice here: {invoice_url}

        Thank you,
        {owner_name}
      BODY
    end

    def due_body
      <<~BODY.strip
        Hello {tenant_name},

        Invoice {invoice_number} for {property_name} is due today, {due_date}.
        The outstanding balance is {balance_due}.

        You can view the invoice here: {invoice_url}

        Thank you,
        {owner_name}
      BODY
    end

    def overdue_body
      <<~BODY.strip
        Hello {tenant_name},

        Invoice {invoice_number} for {property_name} was due on {due_date} and is now {days_overdue} days overdue.
        The outstanding balance is {balance_due}.

        You can view the invoice here: {invoice_url}

        Please arrange payment at your earliest convenience.

        {owner_name}
      BODY
    end
  end
end
