# frozen_string_literal: true

class UserAssociation < ApplicationRecord
  belongs_to :user
  belongs_to :associable, polymorphic: true

  validates :user_id, uniqueness: { scope: %i[associable_type associable_id] }
end
