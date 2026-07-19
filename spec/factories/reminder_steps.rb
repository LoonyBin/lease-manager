# frozen_string_literal: true

FactoryBot.define do
  factory :reminder_step do
    lease
    position { 1 }
    offset_days { -7 }
    repeat_every_days { nil }
    subject { "Invoice {invoice_number} is due on {due_date}" }
    body { "Hello {tenant_name}, {balance_due} is outstanding. See {invoice_url}." }
    to_emails { ["tenant@example.com"] }

    trait :on_due_date do
      offset_days { 0 }
      subject { "Invoice {invoice_number} is due today" }
    end

    trait :overdue do
      offset_days { 7 }
      subject { "Overdue: invoice {invoice_number}" }
    end

    trait :repeating do
      offset_days { 7 }
      repeat_every_days { 14 }
    end

    trait :escalated do
      to_emails { %w[collections@example.com legal@example.com] }
    end
  end
end
