# frozen_string_literal: true

class Entry < ApplicationRecord
  belongs_to :lease
  belongs_to :instrument, polymorphic: true

  validates :amount, presence: true
  validate :amount_not_zero

  scope :initial, -> { where(transaction_id: nil) }
  scope :settlements, -> { where.not(transaction_id: nil) }
  scope :for_transaction, ->(txn_id) { where(transaction_id: txn_id) }

  private

  def amount_not_zero
    errors.add(:amount, "must be other than 0") if amount&.zero?
  end
end
