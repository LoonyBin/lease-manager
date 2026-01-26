# frozen_string_literal: true

class Property < ApplicationRecord
  validates :name, presence: true
  validates :address, presence: true
end
