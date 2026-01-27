# frozen_string_literal: true

class Owner < ApplicationRecord
  has_many :properties, dependent: :nullify

  validates :name, presence: true
  validates :address, presence: true
  validates :invoice_sequence, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
