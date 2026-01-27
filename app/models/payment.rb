# frozen_string_literal: true

class Payment < ApplicationRecord
  belongs_to :lease
  has_many :payment_allocations, dependent: :destroy
  has_many :invoices, through: :payment_allocations

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :date, presence: true
  validates :mode, presence: true

  enum :mode, {
    rtgs: 0,
    neft: 1,
    imps: 2,
    upi: 3,
    cheque: 4,
    cash: 5,
    demand_draft: 6,
    tax_deducted_at_source: 7
  }, default: :rtgs
end
