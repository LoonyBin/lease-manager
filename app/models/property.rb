# frozen_string_literal: true

class Property < ApplicationRecord
  belongs_to :owner

  has_many :leases, dependent: :destroy

  validates :name, presence: true
  validates :address, presence: true
  validates :capacity, presence: true, numericality: { greater_than: 0, only_integer: true }
  validates :unit, presence: true

  def available_capacity(start_date = Date.current, end_date = nil)
    return simple_available_capacity(start_date) unless end_date

    check_dates = [start_date] + leases.where(start_date: start_date..end_date).pluck(:start_date)

    # Calculate usages at each critical date
    max_usage = check_dates.uniq.map { |date| quantity_leased_at(date) }.max || 0
    capacity - max_usage
  end

  private

  def simple_available_capacity(date)
    total_leased = quantity_leased_at(date)
    capacity - total_leased
  end

  def quantity_leased_at(date)
    leases.active_at(date).sum(:quantity)
  end
end
