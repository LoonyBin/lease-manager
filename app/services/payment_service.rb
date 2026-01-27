# frozen_string_literal: true

class PaymentService
  def initialize(payment)
    @payment = payment
  end

  def call
    Payment.transaction do
      allocate_to_invoices
      # Any remaining amount sits on the payment as excess (calculated)
    end
  end

  def self.allocate_excess(invoice)
    Payment.transaction do
      # Find payments for this lease with excess amount
      lease = invoice.lease
      payments = lease.payments.order(:date)

      payments.each do |payment|
        allocate_payment_exception(payment, invoice)
      end
    end
  end

  def self.allocate_payment_exception(payment, invoice)
    return if (excess = payment.amount - payment.payment_allocations.sum(:amount)) <= 0
    return if (needed = invoice.outstanding_amount) <= 0

    allocation = [excess, needed].min
    PaymentAllocation.create!(payment: payment, invoice: invoice, amount: allocation)
    invoice.update_status!
  end

  private

  def allocate_to_invoices
    # Find all unpaid or partially paid invoices for this lease, ordered by date
    invoices = @payment.lease.invoices
                       .where(status: %i[finalized sent partially_paid])
                       .order(:date, :created_at)

    remaining_payment = @payment.amount

    invoices.each do |invoice|
      break if remaining_payment <= 0

      remaining_payment -= allocate_single_invoice(invoice, remaining_payment)
    end
  end

  def allocate_single_invoice(invoice, remaining_payment)
    needed = invoice.outstanding_amount
    allocation_amount = [remaining_payment, needed].min

    PaymentAllocation.create!(
      payment: @payment,
      invoice: invoice,
      amount: allocation_amount
    )

    invoice.update_status!
    allocation_amount
  end
end
