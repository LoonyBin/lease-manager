# frozen_string_literal: true

class Tenant < ApplicationRecord
  validates :name, presence: true
  validates :email, presence: true
  validates :phone_number, presence: true
end
