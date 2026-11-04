# frozen_string_literal: true

class BankStatement < ApplicationRecord
  has_many :bank_transactions, dependent: :destroy

  # The uploaded file is parsed during the request and never stored. Statement
  # text stays out of the audit trail; the filename can carry an account number.
  self.paper_trail_options = paper_trail_options.merge(skip: %w[filename])

  enum :status, { pending: 0, processed: 1 }

  validates :filename, :uploaded_at, presence: true
end
