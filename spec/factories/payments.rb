# frozen_string_literal: true

FactoryBot.define do
  factory :payment do
    lease
    date { Time.zone.today }
    amount { "9.99" }
  end
end
