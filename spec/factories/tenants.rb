# frozen_string_literal: true

FactoryBot.define do
  factory :tenant do
    name { Faker::Name.name }
    email { Faker::Internet.email }
    phone_number { Faker::PhoneNumber.phone_number }
  end
end
