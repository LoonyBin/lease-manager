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
    sequence_column = @invoice.credit_note? ? :credit_note_sequence : :invoice_sequence
    new_sequence = owner.public_send(sequence_column) + 1
    owner.update!(sequence_column => new_sequence)
    new_sequence
  end

  def assign_number(owner, sequence)
    number = format_number(owner, sequence)
    @invoice.assign_attributes(number: number, sequence_number: sequence)
  end

  def format_number(owner, sequence)
    prefix = @invoice.credit_note? ? owner.credit_note_prefix : owner.invoice_prefix
    prefix ||= ""
    prefix + sequence.to_s.rjust(3, "0")
  end
end
