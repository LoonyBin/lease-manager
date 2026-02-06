# frozen_string_literal: true

class Owner < ApplicationRecord
  has_many :properties, dependent: :nullify
  has_many :user_associations, as: :associable, dependent: :destroy
  has_many :users, through: :user_associations

  validates :name, presence: true
  validates :address, presence: true
  validates :invoice_sequence, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :credit_note_sequence, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
