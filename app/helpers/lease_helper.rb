# frozen_string_literal: true

module LeaseHelper
  StatementLine = Data.define(:entry, :balance) do
    delegate :instrument, to: :entry

    def date
      instrument.date
    end

    def description
      case instrument
      when Invoice
        instrument.credit_note? ? "Credit Note ##{instrument.number}" : "Invoice ##{instrument.number}"
      when Payment
        instrument.refund? ? "Refund" : "Payment"
      end
    end

    def icon_name
      case instrument
      when Invoice
        instrument.credit_note? ? "document-minus" : "document-text"
      when Payment
        instrument.refund? ? "arrow-uturn-left" : "banknotes"
      end
    end

    def icon_color_class
      case instrument
      when Invoice
        instrument.credit_note? ? "text-error" : "text-warning"
      when Payment
        instrument.refund? ? "text-error" : "text-success"
      end
    end

    def accent_class
      case instrument
      when Invoice
        instrument.credit_note? ? "statement-credit-note" : "statement-invoice"
      when Payment
        instrument.refund? ? "statement-refund" : "statement-payment"
      end
    end

    def debit?
      entry.amount.positive?
    end

    def debit_amount
      entry.amount if debit?
    end

    def credit_amount
      entry.amount.abs unless debit?
    end
  end

  TYPE_SORT_ORDER = {
    %w[Invoice invoice] => 0,
    %w[Invoice credit_note] => 1,
    %w[Payment payment] => 2,
    %w[Payment refund] => 3
  }.freeze

  private_constant :TYPE_SORT_ORDER

  def statement_entries(entries)
    sorted = entries.sort_by do |e|
      instrument = e.instrument
      type_key = case instrument
                 when Invoice then %w[Invoice] + [instrument.document_type]
                 when Payment then %w[Payment] + [instrument.payment_type]
                 end
      [instrument.date, TYPE_SORT_ORDER.fetch(type_key, 99), e.id]
    end

    running_balance = BigDecimal("0")
    sorted.map do |e|
      running_balance += e.amount
      StatementLine.new(entry: e, balance: running_balance)
    end
  end

  def billable_months(lease)
    return [] unless lease.start_date

    first_month = lease.start_date.beginning_of_month
    last_month = [lease.end_date || Date.current, Date.current].min.beginning_of_month

    months = []
    current = first_month
    while current <= last_month
      months << current
      current = current.next_month
    end
    months
  end
end
