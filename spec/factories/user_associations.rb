# frozen_string_literal: true

FactoryBot.define do
  factory :user_association do
    user
    associable factory: %i[owner]

    trait :with_owner do
      associable factory: %i[owner]
    end

    trait :with_tenant do
      associable factory: %i[tenant]
    end
  end
end
