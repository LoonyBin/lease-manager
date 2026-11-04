# frozen_string_literal: true

class BankStatement < ApplicationRecord
  has_many :bank_transactions, dependent: :destroy

  # The uploaded file is parsed during the request and never stored. Statement
  # text stays out of the audit trail; the filename can carry an account number.
  self.paper_trail_options = paper_trail_options.merge(skip: %w[filename])

  enum :status, { pending: 0, processed: 1 }

  # Statement text can describe activity unrelated to rent, so lines that are
  # not confirmed are deleted this long after upload.
  RETENTION_PERIOD = 90.days

  scope :past_retention, -> { where(uploaded_at: ..RETENTION_PERIOD.ago) }

  def retention_ends_at = uploaded_at + RETENTION_PERIOD

  validates :filename, :uploaded_at, presence: true
end
