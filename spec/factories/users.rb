# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    sequence(:uid) { |n| "user#{n}" }
    provider { "developer" }
    name { "Test User" }
    email { "test@example.com" }
    role { "normal" }
  end
end
