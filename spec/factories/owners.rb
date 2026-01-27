# frozen_string_literal: true

FactoryBot.define do
  factory :owner do
    name { "John Smith Properties" }
    address { "123 Business Rd, New York, NY" }
    invoice_sequence { 0 }
  end
end
