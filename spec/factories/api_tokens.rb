# frozen_string_literal: true

FactoryBot.define do
  factory :api_token do
    user
    sequence(:name) { |n| "Token #{n}" }
    # Mirror the old read_write default: a full-access token. Assigned at
    # creation, which attr_readonly permits (it blocks only later writes).
    permissions { ApiToken::PermissionRegistry.full_preset }
    preset { "full" }

    trait :read_only do
      permissions { ApiToken::PermissionRegistry.read_preset }
      preset { "read_only" }
    end

    # A custom-permission token: pass `permissions:` explicitly, e.g.
    # create(:api_token, :custom, permissions: %w[invoices#index payments#create]).
    trait :custom do
      permissions { [] }
      preset { nil }
    end

    trait :revoked do
      revoked_at { 1.hour.ago }
    end

    trait :expired do
      expires_at { 1.day.ago }
    end
  end
end
