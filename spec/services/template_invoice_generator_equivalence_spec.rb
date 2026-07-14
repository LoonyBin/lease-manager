# frozen_string_literal: true

require "rails_helper"

# Verifies the issue's migration gate: generating from the auto-created
# default template is output-identical to the removed legacy
# InvoiceGenerator, whose arithmetic is ported below as the reference.
# The whole-total "Round Off" line is a new, intentional addition and is
# excluded from the comparison.
RSpec.describe TemplateInvoiceGenerator do
  # Reference implementation: the exact arithmetic of the legacy
  # InvoiceGenerator (rent line + conditional pro-rated discount line),
  # kept verbatim rather than restructured for the metrics cops.
  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def legacy_invoice_attributes(lease, date)
    date = date.beginning_of_month
    rent = lease.current_rent_at(date)
    total_days = date.end_of_month.day
    start_date = [date.beginning_of_month, lease.start_date].max
    end_date = [date.end_of_month, lease.end_date].min
    unused_days = total_days - ((end_date - start_date).to_i + 1)
    prorated_discount = rent * (unused_days / total_days.to_f)

    line_items = [{ name: "Rent for #{date.strftime('%B %Y')}", amount: rent.to_d.round(2),
                    tax_rate: lease.tax_rate, category: "rent" }]
    if prorated_discount.positive?
      line_items << { name: "Pro-rated discount (#{unused_days} days)",
                      amount: (-prorated_discount).to_d.round(2),
                      tax_rate: lease.tax_rate, category: "discount" }
    end

    { date: date, due_date: date + lease.payment_due_in, line_items: line_items }
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  def generated_invoice_attributes(lease, date)
    invoice = described_class.new(lease.invoice_templates.first, date).call
    line_items = invoice.line_items.reject { |line| line.category == "rounding" }.map do |line|
      { name: line.name, amount: line.amount, tax_rate: line.tax_rate&.to_d, category: line.category }
    end
    { date: invoice.date, due_date: invoice.due_date, line_items: line_items }
  end

  def expect_equivalent_output(lease, date)
    expect(generated_invoice_attributes(lease, date)).to eq(legacy_invoice_attributes(lease, date))
  end

  it "matches for a full mid-lease month" do
    lease = create(:lease, rent_amount: 1000, start_date: Date.new(2025, 1, 1), duration_months: 12)
    expect_equivalent_output(lease, Date.new(2025, 6, 1))
  end

  it "matches for the partial first month" do
    lease = create(:lease, rent_amount: 3100, start_date: Date.new(2025, 1, 16), duration_months: 12)
    expect_equivalent_output(lease, Date.new(2025, 1, 1))
  end

  it "matches for an awkwardly prorated first month" do
    lease = create(:lease, rent_amount: 2371.41, start_date: Date.new(2025, 2, 11), duration_months: 12)
    expect_equivalent_output(lease, Date.new(2025, 2, 1))
  end

  it "matches for a mid-month termination" do
    lease = create(:lease, rent_amount: 1000, start_date: Date.new(2025, 1, 1), duration_months: 12)
    lease.update!(terminated_on: Date.new(2025, 5, 10))
    expect_equivalent_output(lease, Date.new(2025, 5, 1))
  end

  it "matches across a percentage enhancement boundary" do
    lease = create(:lease, rent_amount: 1000, start_date: Date.new(2024, 3, 1), duration_months: 24,
                           enhancement_period_months: 12, enhancement_amount: 7.5,
                           enhancement_type: :percentage)
    expect_equivalent_output(lease, Date.new(2025, 4, 1))
  end

  it "matches across a fixed enhancement boundary" do
    lease = create(:lease, rent_amount: 1000, start_date: Date.new(2024, 3, 1), duration_months: 24,
                           enhancement_period_months: 12, enhancement_amount: 250,
                           enhancement_type: :fixed)
    expect_equivalent_output(lease, Date.new(2025, 4, 1))
  end

  it "matches for a renewal lease inheriting enhancements" do
    old_lease = create(:lease, rent_amount: 1000, start_date: Date.new(2024, 1, 1), duration_months: 12,
                               enhancement_period_months: 12, enhancement_amount: 10,
                               enhancement_type: :percentage)
    renewal = Lease.build_renewal(old_lease).tap(&:save!)
    expect_equivalent_output(renewal, Date.new(2025, 3, 1))
  end

  it "matches when the lease has no tax configured" do
    lease = create(:lease, rent_amount: 1000, start_date: Date.new(2025, 1, 16), duration_months: 12,
                           tax_name: nil, tax_rate: nil)
    expect_equivalent_output(lease, Date.new(2025, 1, 1))
  end

  it "matches with a custom payment_due_in" do
    lease = create(:lease, rent_amount: 1000, start_date: Date.new(2025, 1, 1), duration_months: 12,
                           payment_due_in: 1.month + 9.days)
    expect_equivalent_output(lease, Date.new(2025, 2, 1))
  end
end
