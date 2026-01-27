# frozen_string_literal: true

FactoryBot.define do
  factory :lease do
    property
    tenant
    start_date { "2025-01-01" }
    duration_months { 12 }
    rent_amount { "1000.00" }
    security_deposit_in_months { 2 }
    enhancement_period_months { 12 }
    enhancement_amount { "5.0" }
    enhancement_type { :percentage }
  end
end
