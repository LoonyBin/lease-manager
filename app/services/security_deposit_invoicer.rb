# frozen_string_literal: true

class SecurityDepositInvoicer
  def initialize(lease)
    @lease = lease
  end

  def call
    return if event.nil?
    return if amount.nil? || amount.zero?

    create_document
  end

  private

  def create_document
    invoice = Invoice.create!(
      lease: @lease,
      date: date,
      status: :draft,
      document_type: document_type
    )

    create_line_item(invoice)
  end

  def create_line_item(invoice)
    invoice.line_items.create!(
      name: description,
      amount: amount.abs,
      category: "security_deposit"
    )
  end

  def event
    @event ||= if @lease.terminated_on? && @lease.renewal.nil?
                 :termination
               elsif @lease.renewed_from.present?
                 :renewal
               elsif !@lease.terminated_on?
                 :new
               end
  end

  def termination?
    event == :termination
  end

  def renewal?
    event == :renewal
  end

  def new?
    event == :new
  end

  def document_type
    return :invoice if new?
    return :credit_note if termination?

    # it's renewal
    amount.positive? ? :invoice : :credit_note
  end

  def date
    return @lease.terminated_on if termination?

    [Date.current, @lease.start_date].min
  end

  def amount
    @amount ||= if new? || termination?
                  @lease.security_deposit
                else
                  @lease.security_deposit - @lease.renewed_from.security_deposit
                end
  end

  def description
    return "Security Deposit" if new?
    return "Security Deposit Refund" if termination?

    amount.positive? ? "Security Deposit Top-up" : "Security Deposit Refund/Adjustment"
  end
end
