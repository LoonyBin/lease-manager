# frozen_string_literal: true

class LineItem < ApplicationRecord
  belongs_to :invoice

  validates :name, presence: true
  validates :amount, presence: true, numericality: true
  validates :category, presence: true
end
