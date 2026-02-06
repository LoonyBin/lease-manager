# frozen_string_literal: true

class Lease
  module CapacityCheck
    extend ActiveSupport::Concern

    included do
      scope :active_at, lambda { |date|
        where(start_date: ..date)
          .where("terminated_on IS NULL OR terminated_on >= ?", date)
          .where("(date_trunc('month', start_date + (duration_months || ' months')::interval) " \
                 "- interval '1 day')::date >= ?", date)
      }

      validates :quantity, presence: true, numericality: { greater_than: 0, only_integer: true }
      validate :quantity_within_capacity, on: :create
    end

    private

    def quantity_within_capacity
      return unless property && quantity && start_date && duration_months

      available = property.available_capacity(start_date, end_date)
      return unless quantity > available

      errors.add(:quantity,
                 "exceeds available capacity of #{available} #{property.unit.pluralize} during the lease period")
    end
  end
end
