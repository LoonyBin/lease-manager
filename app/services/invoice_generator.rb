# frozen_string_literal: true

class InvoiceGenerator
  def initialize(invoice)
    @invoice = invoice
    @lease = invoice.lease
    @date = invoice.date&.beginning_of_month
  end

  def call
    return @invoice unless @invoice.lease_id? && @invoice.date? && @invoice.invoice?

    existing_invoice = Invoice.rental.find_by(lease: @lease, date: @date)
    return existing_invoice if existing_invoice

    invoice = build_invoice
    build_rent_line_item(invoice)
    build_discount_line_item(invoice)
    invoice
  end

  private

  def build_invoice
    Invoice.new(
      lease: @lease,
      date: @date,
      due_date: @date + @lease.payment_due_in,
      status: :draft
    )
  end

  def rent_amount
    @rent_amount ||= @lease.current_rent_at(@date)
  end

  def build_rent_line_item(invoice)
    invoice.line_items.build(
      name: "Rent for #{@date.strftime('%B %Y')}",
      amount: rent_amount,
      tax_rate: @lease.tax_rate,
      category: "rent"
    )
  end

  def build_discount_line_item(invoice)
    return unless prorated_discount.positive?

    invoice.line_items.build(
      name: "Pro-rated discount (#{unused_days} days)",
      amount: -prorated_discount,
      tax_rate: @lease.tax_rate,
      category: "discount"
    )
  end

  def total_days
    @total_days ||= @date.end_of_month.day
  end

  def unused_days
    @unused_days ||= begin
      start_date = [@date.beginning_of_month, @lease.start_date].max
      end_date = [@date.end_of_month, @lease.end_date].min

      applicable_days = (end_date - start_date).to_i + 1
      total_days - applicable_days
    end
  end

  def prorated_discount
    @prorated_discount ||= @lease.current_rent_at(@date) * (unused_days / total_days.to_f)
  end
end
