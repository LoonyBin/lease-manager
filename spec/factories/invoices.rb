# frozen_string_literal: true

FactoryBot.define do
  factory :invoice do
    lease
    date { Date.current.beginning_of_month }
    status { :draft }

    trait :credit_note do
      document_type { :credit_note }
    end
  end
end
