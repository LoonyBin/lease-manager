# frozen_string_literal: true

FactoryBot.define do
  factory :property do
    owner
    name { "Sunset Villa" }
    address { "123 Sunset Blvd, California" }
  end
end
