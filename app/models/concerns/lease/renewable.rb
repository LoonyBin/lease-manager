# frozen_string_literal: true

class Lease
  module Renewable
    extend ActiveSupport::Concern

    included do
      belongs_to :renewed_from, class_name: "Lease", optional: true, inverse_of: :renewal
      has_one :renewal, class_name: "Lease", foreign_key: :renewed_from_id, dependent: :nullify,
                        inverse_of: :renewed_from

      after_create :terminate_renewed_from_lease, if: :renewed_from_id?
    end

    class_methods do
      def build_renewal(old_lease)
        new(renewal_attributes_from(old_lease).merge(renewed_from: old_lease))
      end

      def renewal_attributes_from(old_lease)
        new_start = old_lease.end_date + 1.day
        old_lease.slice(:property_id, :tenant_id, :duration_months, :security_deposit_value, :security_deposit_type,
                        :enhancement_period_months, :tax_name, :tax_rate,
                        :property_schedule)
                 .merge(start_date: new_start, rent_amount: old_lease.current_rent_at(new_start),
                        enhancement_type: :inherit, enhancement_amount: nil)
      end
    end

    private

    def terminate_renewed_from_lease
      renewed_from.update!(terminated_on: start_date - 1.day)
    end
  end
end
