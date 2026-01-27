# frozen_string_literal: true

class Property < ApplicationRecord
  belongs_to :owner

  has_many :leases, dependent: :destroy

  validates :name, presence: true
  validates :address, presence: true
end
