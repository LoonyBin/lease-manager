# frozen_string_literal: true

class Invoice < ApplicationRecord
  belongs_to :lease
  has_many :line_items, dependent: :destroy
  accepts_nested_attributes_for :line_items, allow_destroy: true
  has_many :payment_allocations, dependent: :destroy
  has_many :payments, through: :payment_allocations

  ransacker :total_amount do
    Arel.sql("(SELECT COALESCE(SUM(line_items.amount), 0) FROM line_items WHERE line_items.invoice_id = invoices.id)")
  end

  enum :status, { draft: 0, finalized: 1, sent: 2, paid: 3, cancelled: 4, partially_paid: 5 }, default: :draft,
                                                                                               validate: true

  validates :date, presence: true
  validates :status, presence: true

  before_save :assign_number, if: -> { finalized? && number.nil? }
  after_save :allocate_excess_payment, if: -> { saved_change_to_status? && finalized? }

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

  private

  def assign_number
    InvoiceNumberingService.new(self).call
  end

  def allocate_excess_payment
    PaymentService.allocate_excess(self)
  end
end
