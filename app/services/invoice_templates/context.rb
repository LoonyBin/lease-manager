# frozen_string_literal: true

module InvoiceTemplates
  # Builds the variables available to template amount expressions and text
  # placeholders, computed for a given lease and invoice month.
  class Context
    VARIABLE_NAMES = %w[
      rent r prorata f days_in_month n occupied_days unused_days invoice_date month_name year
    ].freeze

    def initialize(lease, date)
      @lease = lease
      @date = date.beginning_of_month
    end

    def variables
      @variables ||= {
        "rent" => rent, "r" => rent,
        "prorata" => prorata, "f" => prorata,
        "days_in_month" => days_in_month, "n" => days_in_month,
        "occupied_days" => occupied_days,
        "unused_days" => days_in_month - occupied_days,
        "invoice_date" => @date,
        "month_name" => @date.strftime("%B"),
        "year" => @date.year
      }
    end

    private

    def rent
      @rent ||= @lease.current_rent_at(@date)
    end

    def days_in_month
      @date.end_of_month.day
    end

    # Days of the month covered by the lease term.
    def occupied_days
      @occupied_days ||= begin
        first_day = [@date, @lease.start_date].max
        last_day = [@date.end_of_month, @lease.end_date].compact.min
        ((last_day - first_day).to_i + 1).clamp(0, days_in_month)
      end
    end

    # Occupied fraction of the month (1 for fully covered months).
    def prorata
      @prorata ||= occupied_days.to_d / days_in_month
    end
  end
end
