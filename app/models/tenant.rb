# frozen_string_literal: true

class Tenant < ApplicationRecord
  has_many :leases, dependent: :destroy
  has_many :user_associations, as: :associable, dependent: :destroy
  has_many :users, through: :user_associations

  validates :name, presence: true

  # Ransack allowlist — keep in sync with app/views/tenants/_search.html.haml and _sort.html.haml.
  # No searchable associations.
  def self.ransackable_attributes(_auth_object = nil)
    %w[name email phone_number created_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end
end
