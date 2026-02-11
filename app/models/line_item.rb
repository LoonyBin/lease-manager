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
end
