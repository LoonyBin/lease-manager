# frozen_string_literal: true

class Invoice
  module Totals
    extend ActiveSupport::Concern

    included do
      ransacker :total_amount do
        Arel.sql(<<~SQL.squish)
          (SELECT COALESCE(SUM(
             ROUND(line_items.amount + line_items.amount * COALESCE(line_items.tax_rate, 0) / 100.0, 2)), 0)
           FROM line_items WHERE line_items.invoice_id = invoices.id)
        SQL
      end
    end

    def total_amount
      return in_memory_total if new_record?

      line_items.sum("ROUND(amount + amount * COALESCE(tax_rate, 0) / 100.0, 2)")
    end

    def paid_amount
      return 0 unless total_amount.positive?

      [total_amount - balance, 0].max
    end

    def outstanding_amount
      balance
    end

    def signed_amount
      debit? ? total_amount : -total_amount
    end

    private

    # Mirrors the SQL in +total_amount+ for unsaved invoices (e.g. previews).
    def in_memory_total
      line_items.reject(&:marked_for_destruction?).sum do |item|
        amount = item.amount || 0
        (amount + (amount * (item.tax_rate || 0) / 100)).round(2)
      end
    end
  end
end
