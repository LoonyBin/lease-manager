# frozen_string_literal: true

FactoryBot.define do
  factory :invoice do
    lease
    date { Date.current.beginning_of_month }
    status { :draft }
  end
end
