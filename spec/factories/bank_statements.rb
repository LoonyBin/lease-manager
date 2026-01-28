FactoryBot.define do
  factory :bank_statement do
    sequence(:filename) { |n| "statement_#{n}.csv" }
    uploaded_at { Time.current }
    status { :pending }
  end
end
