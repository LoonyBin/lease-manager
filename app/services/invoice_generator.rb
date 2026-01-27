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
      create_rent_line_item(invoice)
      create_tax_line_item(invoice) if @lease.tax_rate.to_f.positive?
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
  end

  def create_tax_line_item(invoice)
    rent_amount = @lease.current_rent_at(@date)
    tax_amount = rent_amount * (@lease.tax_rate / 100.0)
    tax_name = @lease.tax_name.presence || "Tax"

    LineItem.create!(
      invoice: invoice,
      name: "#{tax_name} (#{@lease.tax_rate}%)",
      amount: tax_amount,
      category: "tax"
    )
  end
end
