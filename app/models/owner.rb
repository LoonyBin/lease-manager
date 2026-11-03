# frozen_string_literal: true

class Owner < ApplicationRecord
  has_many :properties, dependent: :nullify
  has_many :user_associations, as: :associable, dependent: :destroy
  has_many :users, through: :user_associations

  validates :name, presence: true
  validates :invoice_sequence, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :credit_note_sequence, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # Ransack allowlist — keep in sync with app/views/owners/_search.html.haml, _sort.html.haml,
  # and owners_controller.rb's default sort (name asc). No searchable associations.
  def self.ransackable_attributes(_auth_object = nil)
    %w[name address created_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end
end
