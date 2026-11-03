# frozen_string_literal: true

class Invoice
  module Totals
    extend ActiveSupport::Concern

    # Gross of every line item: amount plus its tax, rounded per line so the
    # result matches +in_memory_total+ to the cent. Shared by the ransacker and
    # by +with_total_amount+ so sorting, filtering and reading can never
    # disagree about what an invoice is worth.
    TOTAL_AMOUNT_SQL = <<~SQL.squish
      (SELECT COALESCE(SUM(
         ROUND(line_items.amount + line_items.amount * COALESCE(line_items.tax_rate, 0) / 100.0, 2)), 0)
       FROM line_items WHERE line_items.invoice_id = invoices.id)
    SQL

    included do
      ransacker :total_amount do
        Arel.sql(TOTAL_AMOUNT_SQL)
      end

      # Resolves every row's gross inside the listing query, so rendering a page
      # of invoices costs one query rather than one SUM per invoice. Read path
      # only: the alias is a snapshot of the line items as they were when the
      # record loaded, so don't use it on a record you are about to mutate.
      scope :with_total_amount, lambda {
        select(arel_table[Arel.star], Arel.sql("#{TOTAL_AMOUNT_SQL} AS total_amount"))
      }
    end

    def total_amount
      return in_memory_total if new_record?
      return self[:total_amount] if has_attribute?(:total_amount)

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

    # +total_amount+ is derived, so the default column-only payload omits it and
    # leaves a JSON client holding +balance+ with nothing to read it against: a
    # zero balance on a settled invoice and on an empty one look identical.
    # Callers keep control of :only / :include / their own :methods.
    def serializable_hash(options = nil)
      options = (options || {}).symbolize_keys
      options[:methods] = Array(options[:methods]) | [:total_amount]
      super
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
