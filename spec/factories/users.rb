# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    sequence(:uid) { |n| "user#{n}" }
    provider { "developer" }
    name { "Test User" }
    email { "test@example.com" }
    role { "normal" }

    trait :admin do
      role { "admin" }
    end

    trait :normal do
      role { "normal" }
    end
  end
end
