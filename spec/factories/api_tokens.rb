# frozen_string_literal: true

FactoryBot.define do
  factory :api_token do
    user
    sequence(:name) { |n| "Token #{n}" }

    trait :revoked do
      revoked_at { 1.hour.ago }
    end

    trait :expired do
      expires_at { 1.day.ago }
    end
  end
end
