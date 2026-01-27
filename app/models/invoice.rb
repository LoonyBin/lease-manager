# frozen_string_literal: true

class Invoice < ApplicationRecord
  belongs_to :lease
  has_many :line_items, dependent: :destroy

  enum :status, { draft: 0, finalized: 1, sent: 2, paid: 3, cancelled: 4 }, default: :draft, validate: true

  validates :date, presence: true
  validates :status, presence: true
end
