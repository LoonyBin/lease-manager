# frozen_string_literal: true

class BankTransaction < ApplicationRecord
  belongs_to :bank_statement
  belongs_to :matched_payment, class_name: "Payment", optional: true

  enum :status, { unmatched: 0, matched: 1, confirmed: 2, rejected: 3 }

  validates :date, presence: true
  validates :amount, presence: true, numericality: true

  scope :pending_review, -> { where(status: %i[unmatched matched]) }
end
