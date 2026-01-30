# frozen_string_literal: true

class Tenant < ApplicationRecord
  has_many :leases, dependent: :destroy
  has_many :user_associations, as: :associable, dependent: :destroy
  has_many :users, through: :user_associations

  validates :name, presence: true
  validates :email, presence: true
  validates :phone_number, presence: true
end
