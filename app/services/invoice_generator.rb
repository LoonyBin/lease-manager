# frozen_string_literal: true

class InvoiceGenerator
  def initialize(lease, date)
    @lease = lease
    @date = date.beginning_of_month
  end

  def call
    existing_invoice = Invoice.find_by(lease: @lease, date: @date)
    return existing_invoice if existing_invoice

    Invoice.transaction do
      invoice = create_invoice
      rent_amount = create_rent_line_item(invoice)
      discount_amount = create_discount_line_item(invoice)
      create_tax_line_item(invoice, rent_amount - discount_amount) if @lease.tax_rate.to_f.positive?
      invoice
    end
  end

  private

  def create_invoice
    Invoice.create!(
      lease: @lease,
      date: @date,
      status: :draft
    )
  end

  def create_rent_line_item(invoice)
    amount = @lease.current_rent_at(@date)

    LineItem.create!(
      invoice: invoice,
      name: "Rent for #{@date.strftime('%B %Y')}",
      amount: amount,
      category: "rent"
    )

    amount
  end

  def create_discount_line_item(invoice)
    discount = @lease.proration_discount_for(@date)
    return 0 unless discount.positive?

    unused_days = calculate_unused_days

    LineItem.create!(
      invoice: invoice,
      name: "Pro-rated discount (#{unused_days} days)",
      amount: -discount,
      category: "discount"
    )

    discount
  end

  def calculate_unused_days
    days_in_month = @date.end_of_month.day
    month_start = @date.beginning_of_month
    days = 0
    days += @lease.start_date.day - 1 if first_month_partial?(month_start)
    days += days_in_month - @lease.end_date.day if last_month_partial?(month_start, days_in_month)
    days
  end

  def first_month_partial?(month_start)
    month_start == @lease.start_date.beginning_of_month && @lease.start_date.day > 1
  end

  def last_month_partial?(month_start, days_in_month)
    @lease.end_date && month_start == @lease.end_date.beginning_of_month && @lease.end_date.day < days_in_month
  end

  def create_tax_line_item(invoice, taxable_amount)
    tax_amount = taxable_amount * (@lease.tax_rate / 100.0)
    tax_name = @lease.tax_name.presence || "Tax"

    LineItem.create!(
      invoice: invoice,
      name: "#{tax_name} (#{@lease.tax_rate}%)",
      amount: tax_amount,
      category: "tax"
    )
  end
end
