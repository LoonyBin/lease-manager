# frozen_string_literal: true

class LeaseRenewalService
  def initialize(lease)
    @lease = lease
  end

  def call
    ActiveRecord::Base.transaction do
      terminate_old_lease
      create_renewed_lease
    end
  end

  private

  def terminate_old_lease
    @lease.update!(terminated_on: @lease.end_date)
  end

  def create_renewed_lease
    Lease.create!(renewal_attributes)
  end

  def renewal_attributes
    base_attributes.merge(enhancement_attributes).merge(tax_attributes)
  end

  def base_attributes
    {
      property: @lease.property,
      tenant: @lease.tenant,
      start_date: @lease.end_date + 1.day,
      duration_months: @lease.duration_months,
      rent_amount: @lease.current_rent_at(@lease.end_date),
      security_deposit_in_months: @lease.security_deposit_in_months
    }
  end

  def enhancement_attributes
    {
      enhancement_period_months: @lease.enhancement_period_months,
      enhancement_amount: @lease.enhancement_amount,
      enhancement_type: @lease.enhancement_type
    }
  end

  def tax_attributes
    { tax_name: @lease.tax_name, tax_rate: @lease.tax_rate }
  end
end
