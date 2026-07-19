# frozen_string_literal: true

FactoryBot.define do
  factory :invoice_notification do
    invoice
    reminder_step { association :reminder_step, lease: invoice.lease }
    channel { :email }
    status { :pending }
    occurrence_on { Date.current }
    recipient_email { "tenant@example.com" }
    subject { "Invoice 2026-001 is due" }
    body { "Hello, your invoice is due." }

    trait :approved do
      status { :approved }
    end

    trait :sent do
      status { :sent }
      sent_at { Time.current }
    end

    trait :failed do
      status { :failed }
      last_error { "550 mailbox unavailable" }
    end

    trait :cancelled do
      status { :cancelled }
    end
  end
end
