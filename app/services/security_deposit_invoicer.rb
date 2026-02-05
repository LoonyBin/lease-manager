# frozen_string_literal: true

class SecurityDepositInvoicer
  def initialize(lease)
    @lease = lease
  end

  def call
    if @lease.terminated_on? && @lease.renewal.nil?
      # Lease terminated and not being renewed
      handle_termination_refund
    elsif @lease.renewed_from
      handle_renewal_deposit
    elsif !@lease.terminated_on?
      # New lease (not terminated immediately, ensuring strict creation flow)
      handle_new_lease_deposit
    end
  end

  private

  def invoice_date
    [Date.current, @lease.start_date].min
  end

  def handle_new_lease_deposit
    amount = @lease.security_deposit
    return if amount <= 0

    create_invoice(amount, "Security Deposit")
  end

  def handle_renewal_deposit
    old_lease = @lease.renewed_from
    old_deposit = old_lease.security_deposit
    new_deposit = @lease.security_deposit
    difference = new_deposit - old_deposit

    if difference.positive?
      create_invoice(difference, "Security Deposit Top-up")
    elsif difference.negative?
      create_credit_note(difference.abs, "Security Deposit Refund/Adjustment")
    end
  end

  def handle_termination_refund
    amount = @lease.security_deposit
    return if amount <= 0

    create_credit_note(amount, "Security Deposit Refund")
  end

  def create_invoice(amount, description)
    invoice = Invoice.create!(
      lease: @lease,
      date: invoice_date,
      status: :draft,
      document_type: :invoice
    )
    create_line_item(invoice, amount, description)
  end

  def create_credit_note(amount, description)
    invoice = Invoice.create!(
      lease: @lease,
      date: invoice_date, # Or terminated_on? usually current processing date
      status: :draft,
      document_type: :credit_note
    )
    create_line_item(invoice, amount, description)
  end

  def create_line_item(invoice, amount, description)
    invoice.line_items.create!(
      name: description,
      amount: amount,
      category: "security_deposit"
    )
  end
end
