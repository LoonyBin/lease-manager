# frozen_string_literal: true

FactoryBot.define do
  factory :invoice do
    lease
    date { Date.current.beginning_of_month }
    status { :draft }

    trait :credit_note do
      document_type { :credit_note }
    end

    trait :with_balance do
      transient do
        balance_amount { 0 }
      end

      # rubocop:disable Rails/SkipsModelValidations -- Test setup: balance is normally computed via entries
      after(:create) do |invoice, evaluator|
        invoice.update_column(:balance, evaluator.balance_amount)
      end
      # rubocop:enable Rails/SkipsModelValidations
    end
  end
end
