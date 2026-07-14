# frozen_string_literal: true

FactoryBot.define do
  factory :invoice_template do
    lease
    name { "Rent" }
    payment_due_in { 9.days }

    # Templates require at least one line item; build a plain rent line
    # unless the spec supplied its own.
    after(:build) do |template|
      if template.line_items.empty?
        template.line_items.build(name: "Rent for {month_name} {year}", amount_expression: "rent",
                                  tax_rate: 18, category: "rent", position: 1)
      end
    end

    trait :with_discount_line do
      after(:build) do |template|
        template.line_items.build(name: "Pro-rated discount ({unused_days} days)",
                                  amount_expression: "rent * (prorata - 1)",
                                  tax_rate: 18, category: "discount", position: 2)
      end
    end
  end

  factory :invoice_template_line_item do
    invoice_template
    name { "Maintenance" }
    amount_expression { "2500" }
    tax_rate { 0 }
    category { "maintenance" }
  end
end
