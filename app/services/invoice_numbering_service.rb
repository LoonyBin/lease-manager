# frozen_string_literal: true

class InvoiceNumberingService
  def initialize(invoice)
    @invoice = invoice
  end

  def call
    return if @invoice.number.present?
    return unless (owner = @invoice.lease.property.owner)

    owner.with_lock do
      new_sequence = increment_sequence(owner)
      assign_number(owner, new_sequence)
    end
  end

  private

  def increment_sequence(owner)
    new_sequence = owner.invoice_sequence + 1
    owner.update!(invoice_sequence: new_sequence)
    new_sequence
  end

  def assign_number(owner, sequence)
    number = format_number(owner, sequence)
    @invoice.update!(number: number, sequence_number: sequence)
  end

  def format_number(owner, sequence)
    prefix = owner.name.gsub(/[^a-zA-Z]/, "").upcase[0..2]
    prefix = "OWN" if prefix.blank?
    "#{prefix}-#{sequence.to_s.rjust(3, '0')}"
  end
end
