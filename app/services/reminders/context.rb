# frozen_string_literal: true

module Reminders
  # Builds the variables available to reminder message placeholders for a
  # given invoice: the invoice-template variables for the invoice's month
  # (so `{rent}`, `{month_name}` and friends keep working in reminder text)
  # plus invoice- and reminder-specific ones.
  class Context
    REMINDER_VARIABLE_NAMES = %w[
      invoice_number invoice_date due_date total_amount balance_due days_overdue
      tenant_name property_name owner_name invoice_url
    ].freeze

    VARIABLE_NAMES = (InvoiceTemplates::Context::VARIABLE_NAMES | REMINDER_VARIABLE_NAMES).freeze

    # How a lease with unusable rent data fails while computing the month's
    # figures: a missing start date or rent amount surfaces as a nil
    # comparison/arithmetic error, a zero enhancement period as a division by
    # zero. Anything outside this set is a bug or an infrastructure fault and
    # must not be papered over with a partial variable set.
    RENT_COMPUTATION_ERRORS = [NoMethodError, TypeError, ArgumentError, ZeroDivisionError].freeze

    def initialize(invoice, today: Date.current)
      @invoice = invoice
      @today = today
    end

    # Reminder variables win over the invoice-month ones where they overlap
    # (`invoice_date` is the invoice's own date, not the start of its month).
    def variables
      @variables ||= template_variables.merge(reminder_variables)
    end

    private

    def template_variables
      InvoiceTemplates::Context.new(@invoice.lease, @invoice.date).variables
    rescue *RENT_COMPUTATION_ERRORS => e
      # A lease whose rent cannot be computed for the month must not block a
      # reminder; the invoice-specific variables below are enough on their own.
      Rails.logger.warn("Reminder context fell back for invoice #{@invoice.id}: #{e.message}")
      {}
    end

    def reminder_variables
      invoice_variables.merge(party_variables)
    end

    def invoice_variables
      {
        "invoice_number" => @invoice.number.presence || "draft",
        "invoice_date" => @invoice.date,
        "due_date" => @invoice.due_date,
        "total_amount" => @invoice.total_amount,
        "balance_due" => @invoice.balance,
        "days_overdue" => days_overdue,
        "invoice_url" => invoice_url
      }
    end

    def party_variables
      lease = @invoice.lease
      {
        "tenant_name" => lease.tenant.name,
        "property_name" => lease.property.name,
        "owner_name" => lease.property.owner.name
      }
    end

    # Zero until the due date passes, so `{days_overdue}` reads sensibly in
    # near-due messages too.
    def days_overdue
      return 0 if @invoice.due_date.blank?

      [(@today - @invoice.due_date).to_i, 0].max
    end

    # Reminders link back to the app rather than attaching a rendered
    # document; the host comes from the mailer's URL options.
    def invoice_url
      Rails.application.routes.url_helpers.invoice_url(@invoice, **mailer_url_options)
    rescue ArgumentError => e
      Rails.logger.warn("Reminder invoice URL unavailable for invoice #{@invoice.id}: #{e.message}")
      ""
    end

    def mailer_url_options
      ActionMailer::Base.default_url_options.presence || {}
    end
  end
end
