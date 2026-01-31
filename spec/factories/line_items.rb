# frozen_string_literal: true

FactoryBot.define do
  factory :line_item do
    invoice
    name { "Rent" }
    amount { Faker::Number.between(from: 800, to: 3000).round(-2) }
    category { "rent" }
    tax_rate { 18.0 }
  end
end
