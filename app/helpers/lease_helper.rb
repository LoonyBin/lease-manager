# frozen_string_literal: true

module LeaseHelper
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
