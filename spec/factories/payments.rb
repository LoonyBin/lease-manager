# frozen_string_literal: true

FactoryBot.define do
  factory :payment do
    lease
    date { Faker::Date.between(from: 6.months.ago, to: Time.zone.today) }
    amount { Faker::Number.between(from: 800, to: 3000).round(-2) }
    mode { %w[rtgs neft imps upi cheque cash].sample }
    reference_number { Faker::Alphanumeric.alphanumeric(number: 12).upcase }

    trait :refund do
      payment_type { :refund }
    end
  end
end
