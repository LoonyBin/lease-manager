# frozen_string_literal: true

class Invoice < ApplicationRecord
  belongs_to :lease
  has_many :line_items, dependent: :destroy
  has_many :payment_allocations, dependent: :destroy
  has_many :payments, through: :payment_allocations

  enum :status, { draft: 0, finalized: 1, sent: 2, paid: 3, cancelled: 4, partially_paid: 5 }, default: :draft,
                                                                                               validate: true

  validates :date, presence: true
  validates :status, presence: true

  def total_amount
    line_items.sum(:amount)
  end

  def paid_amount
    payment_allocations.sum(:amount)
  end

  def outstanding_amount
    total_amount - paid_amount
  end

  def update_status!
    if outstanding_amount <= 0 && total_amount.positive?
      paid!
    elsif paid_amount.positive?
      partially_paid!
    end
  end
end
