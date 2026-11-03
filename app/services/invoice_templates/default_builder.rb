# frozen_string_literal: true

module InvoiceTemplates
  # Builds the default template for a lease, reproducing the legacy
  # hard-coded generator output: a rent line plus a pro-rated discount line.
  # The discount evaluates to zero (and is dropped) in fully occupied months.
  class DefaultBuilder
    def initialize(lease)
      @lease = lease
    end

    def call
      template = @lease.invoice_templates.build(name: "Rent", payment_due_in: @lease.payment_due_in)
      build_rent_line(template)
      build_discount_line(template)
      template
    end

    private

    def build_rent_line(template)
      template.line_items.build(name: "Rent for {month_name} {year}", amount_expression: "rent",
                                tax_rate: @lease.tax_rate, category: "rent", position: 1)
    end

    def build_discount_line(template)
      template.line_items.build(name: "Pro-rated discount ({unused_days} days)",
                                amount_expression: "rent * (prorata - 1)",
                                tax_rate: @lease.tax_rate, category: "discount", position: 2)
    end
  end
end
