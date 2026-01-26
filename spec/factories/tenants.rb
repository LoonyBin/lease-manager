FactoryBot.define do
  factory :tenant do
    name { "John Doe" }
    email { "john@example.com" }
    phone_number { "555-1234" }
  end
end
