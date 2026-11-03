# frozen_string_literal: true

module LeasesHelper
  def lease_status(lease)
    return "archived" if lease.archived?
    return "terminated" if lease.terminated_on.present?
    return "expired" if lease.end_date && lease.end_date < Date.current
    return "upcoming" if lease.start_date > Date.current

    "active"
  end
end
