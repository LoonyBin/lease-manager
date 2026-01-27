# frozen_string_literal: true

class Payment < ApplicationRecord
  belongs_to :lease
  has_many :payment_allocations, dependent: :destroy
  has_many :invoices, through: :payment_allocations

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :date, presence: true
end
