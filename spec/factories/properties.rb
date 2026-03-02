# frozen_string_literal: true

FactoryBot.define do
  factory :property do
    owner
    name { "#{Faker::Address.community} #{%w[Apartments Villa Tower Complex].sample}" }
    address { Faker::Address.full_address }
  end
end
