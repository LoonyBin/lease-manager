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
