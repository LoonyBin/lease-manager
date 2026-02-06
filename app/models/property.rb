# frozen_string_literal: true

class Property < ApplicationRecord
  belongs_to :owner

  has_many :leases, dependent: :destroy

  validates :name, presence: true
  validates :address, presence: true
  validates :capacity, presence: true, numericality: { greater_than: 0, only_integer: true }
  validates :unit, presence: true

  def available_capacity(date = Date.current)
    total_leased = leases.active_at(date).sum(:quantity)
    capacity - total_leased
  end
end
