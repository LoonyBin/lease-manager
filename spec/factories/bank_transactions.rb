# frozen_string_literal: true

FactoryBot.define do
  factory :bank_transaction do
    bank_statement
    date { Date.current }
    amount { 10_000.00 }
    description { "Payment received" }
    reference { "UTR123456" }
    status { :unmatched }
  end
end
