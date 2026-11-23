# frozen_string_literal: true

class Lease
  module RentCalculation
    extend ActiveSupport::Concern

    included do
      enum :enhancement_type, { percentage: 0, fixed: 1, inherit: 2 }
      enum :security_deposit_type, { months: 0, fixed: 1 }, prefix: :security_deposit

      validates :rent_amount, presence: true, numericality: { greater_than: 0 }
      # Rent is compounded once per period, so the lease length bounds that work.
      validates :duration_months, numericality: { less_than_or_equal_to: 1200 }, allow_nil: true
      # Periods are counted from start_date, so the start and termination dates are held
      # to the same window as invoice dates.
      validates :start_date, :terminated_on, inclusion: { in: Invoice::DATE_RANGE }, allow_nil: true
      validates :enhancement_period_months, presence: true, numericality: { only_integer: true, greater_than: 0 }
      validates :security_deposit_value, presence: true,
                                         numericality: { greater_than_or_equal_to: 0 }
      validates :enhancement_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true,
                                     unless: :inherit?
      validates :renewed_from, presence: true, if: :inherit?
      validates :tax_rate, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true
    end

    def current_rent_at(date)
      source = inheritance_source
      return source.rent_amount if date < source.start_date

      periods = source.months_between(source.start_date, date) / source.enhancement_period_months
      source.calculate_enhanced_rent(periods)
    end

    # The lease an inheriting lease takes its rent from: the oldest ancestor of
    # the chain. The walk stops as soon as it reaches a lease it has already
    # visited, so a chain that loops cannot recurse forever. A chain that loops
    # has no oldest ancestor, so the lease keeps its own rent, which is what an
    # inheriting lease would do anyway.
    def inheritance_source
      lease = self
      visited = Set.new
      visited << lease.id if lease.id.present?

      while lease.inherit? && lease.renewed_from.present?
        parent = lease.renewed_from
        return self if visited.include?(parent.id)

        visited << parent.id
        lease = parent
      end

      lease
    end

    def months_between(from, to)
      ((to.year * 12) + to.month) - ((from.year * 12) + from.month)
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
      return 0 unless security_deposit_value&.positive?

      security_deposit_months? ? rent_amount * security_deposit_value : security_deposit_value
    end
  end
end
