# frozen_string_literal: true

class Lease < ApplicationRecord
  belongs_to :property
  belongs_to :tenant
  has_many :invoices, dependent: :destroy
  has_many :payments, dependent: :destroy
  has_many :payment_allocations, through: :payments

  enum :enhancement_type, { percentage: 0, fixed: 1 }

  validates :start_date, presence: true
  validates :rent_amount, presence: true, numericality: { greater_than: 0 }
  validates :duration_months, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :security_deposit_in_months, presence: true,
                                         numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :enhancement_period_months, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :enhancement_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :tax_rate, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true

  validate :termination_date_after_start_date

  def end_date
    return terminated_on if terminated_on.present?
    return nil unless start_date && duration_months

    (start_date + (duration_months - 1).months).end_of_month
  end

  def security_deposit
    return 0 unless rent_amount && security_deposit_in_months

    rent_amount * security_deposit_in_months
  end

  def current_rent_at(date)
    return rent_amount if date < start_date

    months_elapsed = ((date.year * 12) + date.month) - ((start_date.year * 12) + start_date.month)
    periods = months_elapsed / enhancement_period_months

    calculate_enhanced_rent(periods)
  end

  def billable_months
    return [] unless start_date

    first_month = start_date.beginning_of_month
    last_month = [end_date || Date.current, Date.current].min.beginning_of_month

    months = []
    current = first_month
    while current <= last_month
      months << current
      current = current.next_month
    end
    months
  end

  def missing_invoice_months
    existing_dates = invoices.pluck(:date).map(&:beginning_of_month)
    billable_months - existing_dates
  end

  def proration_discount_for(date)
    month_start = date.beginning_of_month
    month_end = date.end_of_month
    days_in_month = month_end.day
    daily_rate = current_rent_at(date) / days_in_month.to_f

    unused_days = 0

    # First month: discount for days before start_date
    unused_days += start_date.day - 1 if month_start == start_date.beginning_of_month && start_date.day > 1

    # Last month: discount for days after end_date
    if end_date && month_start == end_date.beginning_of_month && end_date.day < days_in_month
      unused_days += days_in_month - end_date.day
    end

    (unused_days * daily_rate).round(2)
  end

  private

  def calculate_enhanced_rent(periods)
    periods.times.reduce(rent_amount) do |current_rent, _|
      current_rent + calculate_increase(current_rent)
    end
  end

  def calculate_increase(current_rent)
    return 0 unless enhancement_amount.to_f.positive?

    if percentage?
      current_rent * (enhancement_amount / 100.0)
    elsif fixed?
      enhancement_amount
    else
      0
    end
  end

  def termination_date_after_start_date
    return if terminated_on.blank? || start_date.blank?

    return unless terminated_on <= start_date

    errors.add(:terminated_on, "must be after the start date")
  end
end
