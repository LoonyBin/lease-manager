# frozen_string_literal: true

FactoryBot.define do
  factory :line_item do
    invoice
    name { "Rent" }
    amount { "1000.00" }
    category { "rent" }
  end
end
