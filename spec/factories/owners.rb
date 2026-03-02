# frozen_string_literal: true

FactoryBot.define do
  factory :owner do
    name { "#{Faker::Name.last_name} Properties LLC" }
    address { Faker::Address.full_address }
    invoice_sequence { 0 }
  end
end
