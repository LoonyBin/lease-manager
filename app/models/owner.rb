# frozen_string_literal: true

class Owner < ApplicationRecord
  has_many :properties, dependent: :nullify

  validates :name, presence: true
  validates :address, presence: true
end
