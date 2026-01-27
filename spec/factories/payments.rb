# frozen_string_literal: true

FactoryBot.define do
  factory :payment do
    lease
    date { Time.zone.today }
    amount { "9.99" }
    mode { "upi" }
    reference_number { "UPI123456" }
  end
end
