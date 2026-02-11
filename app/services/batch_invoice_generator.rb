# frozen_string_literal: true

class BatchInvoiceGenerator
  def initialize(date = Date.current)
    @date = date
  end

  def call
    Lease.active_at(@date).find_each do |lease|
      invoice = InvoiceGenerator.new(Invoice.new(lease: lease, date: @date)).call
      invoice.save! if invoice.new_record?
    end
  end
end
