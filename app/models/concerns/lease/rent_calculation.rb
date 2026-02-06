# frozen_string_literal: true

class Lease
  module RentCalculation
    extend ActiveSupport::Concern

    included do
      enum :enhancement_type, { percentage: 0, fixed: 1 }

      validates :rent_amount, presence: true, numericality: { greater_than: 0 }
      validates :enhancement_period_months, presence: true, numericality: { only_integer: true, greater_than: 0 }
      validates :security_deposit_in_months, presence: true,
                                             numericality: { only_integer: true, greater_than_or_equal_to: 0 }
      validates :enhancement_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
      validates :tax_rate, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true
    end

    def current_rent_at(date)
      return rent_amount if date < start_date

      months_elapsed = ((date.year * 12) + date.month) - ((start_date.year * 12) + start_date.month)
      periods = months_elapsed / enhancement_period_months

      calculate_enhanced_rent(periods)
    end

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

    def security_deposit
      return 0 unless rent_amount && security_deposit_in_months

      rent_amount * security_deposit_in_months
    end
  end
end
