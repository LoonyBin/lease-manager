# frozen_string_literal: true

class LineItem < ApplicationRecord
  belongs_to :invoice, touch: true

  validates :name, presence: true
  validates :amount, presence: true, numericality: true
  validates :category, presence: true

  def tax_amount
    return 0 if tax_rate.blank?

    (amount * (tax_rate / 100.0)).round(2)
  end

  def total
    amount + tax_amount
  end

  def taxable?
    %w[rent].include?(category)
  end

  # Ships the derived figures the invoice page shows, so a JSON client reading
  # nested line items doesn't have to re-derive them from +amount+ and
  # +tax_rate+ and hope it rounds the same way this does. Hooks
  # +serializable_hash+ rather than +as_json+ because that is what a parent's
  # :include option calls on each associated record; +as_json+ routes here too.
  def serializable_hash(options = nil)
    options = (options || {}).symbolize_keys
    options[:methods] = Array(options[:methods]) | %i[tax_amount total]
    super
  end
end
