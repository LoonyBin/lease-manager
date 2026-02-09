# frozen_string_literal: true

module LeasesHelper
  def lease_status(lease)
    if lease.terminated_on.present?
      "terminated"
    elsif lease.end_date && lease.end_date < Date.current
      "expired"
    else
      "active"
    end
  end
end
