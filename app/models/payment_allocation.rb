# frozen_string_literal: true

class PaymentAllocation < ApplicationRecord
  belongs_to :payment
  belongs_to :invoice

  validates :amount, presence: true, numericality: { greater_than: 0 }
end
