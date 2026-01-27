# frozen_string_literal: true

FactoryBot.define do
  factory :payment_allocation do
    payment
    invoice
    amount { "9.99" }
  end
end
