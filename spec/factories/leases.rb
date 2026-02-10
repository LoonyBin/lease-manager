# frozen_string_literal: true

FactoryBot.define do
  factory :lease do
    property
    tenant
    start_date { "2025-01-01" }
    duration_months { 12 }
    rent_amount { "1000.00" }
    security_deposit_value { 2 }
    enhancement_period_months { 12 }
    enhancement_amount { "5.0" }
    enhancement_type { :percentage }
    tax_name { "GST" }
    tax_rate { 18.0 }

    trait :randomized do
      start_date { Faker::Date.between(from: 2.years.ago, to: 6.months.ago).beginning_of_month }
      duration_months { [12, 24, 36].sample }
      rent_amount { Faker::Number.between(from: 800, to: 3000).round(-2) }
      security_deposit_value { [1, 2, 3].sample }
      enhancement_amount { [5.0, 7.5, 10.0].sample }
    end
  end
end
