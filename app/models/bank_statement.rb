# frozen_string_literal: true

class BankStatement < ApplicationRecord
  has_many :bank_transactions, dependent: :destroy
  has_one_attached :file

  enum :status, { pending: 0, processed: 1 }

  validates :filename, presence: true
end
