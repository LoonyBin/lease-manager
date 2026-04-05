# frozen_string_literal: true

class MissingInvoiceDetector
  MissingInvoice = Struct.new(:lease, :date, :tenant, :property, :expected_amount)

  def initialize(leases = nil)
    @leases = leases || non_upcoming_leases
  end

  def call
    return [] if @leases.empty?

    existing = existing_rental_invoices
    @leases.flat_map { |lease| missing_for_lease(lease, existing) }.sort_by(&:date)
  end

  private

  def non_upcoming_leases
    upcoming_ids = Lease.by_status("upcoming").select(:id)
    Lease.where.not(id: upcoming_ids).includes(:property, :tenant)
  end

  def missing_for_lease(lease, existing)
    expected_months(lease).filter_map do |month|
      next if existing.include?([lease.id, month])

      MissingInvoice.new(
        lease: lease,
        date: month,
        tenant: lease.tenant,
        property: lease.property,
        expected_amount: lease.current_rent_at(month)
      )
    end
  end

  def expected_months(lease)
    return [] unless lease.start_date

    end_date = [lease.end_date, Time.zone.today].compact.min
    return [] if end_date < lease.start_date

    month_range(lease.start_date.beginning_of_month, end_date.beginning_of_month)
  end

  def month_range(start_month, end_month)
    months = []
    current = start_month
    while current <= end_month
      months << current
      current = current.next_month
    end
    months
  end

  def existing_rental_invoices
    @existing_rental_invoices ||=
      Invoice.rental
             .where(lease: @leases)
             .pluck(:lease_id, :date)
             .to_set { |lease_id, date| [lease_id, date.to_date.beginning_of_month] }
  end
end
