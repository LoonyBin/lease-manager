# frozen_string_literal: true

class Lease < ApplicationRecord
  belongs_to :property
  belongs_to :tenant
  has_many :invoices, dependent: :destroy

  validates :start_date, presence: true
  validates :rent_amount, presence: true, numericality: { greater_than: 0 }
  validates :duration_months, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :security_deposit_in_months, presence: true,
                                         numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :enhancement_period_months, numericality: { only_integer: true, greater_than: 0 }

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
      increase = 0
      increase += current_rent * (enhancement_percentage / 100.0) if enhancement_percentage.to_f.positive?
      increase += enhancement_fixed_amount if enhancement_fixed_amount.to_f.positive?
      current_rent + increase
    end
  end

  def termination_date_after_start_date
    return if terminated_on.blank? || start_date.blank?

    return unless terminated_on <= start_date

    errors.add(:terminated_on, "must be after the start date")
  end
end
