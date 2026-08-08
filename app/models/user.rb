# frozen_string_literal: true

class User < ApplicationRecord
  has_many :user_associations, dependent: :destroy
  has_many :api_tokens, dependent: :destroy
  has_many :owners, through: :user_associations, source: :associable, source_type: "Owner"
  has_many :tenants, through: :user_associations, source: :associable, source_type: "Tenant"

  validates :uid, presence: true
  validates :provider, presence: true
  validates :uid, uniqueness: { scope: :provider }

  enum :role, { admin: 0, normal: 1 }, default: :normal

  # Ransack allowlist — keep in sync with app/views/users/_search.html.haml and _sort.html.haml.
  # Deliberately no associations: api_tokens (token_digest) must never be searchable (see #173).
  def self.ransackable_attributes(_auth_object = nil)
    %w[name email role created_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end

  def self.from_omniauth(auth)
    user = find_or_initialize_by(provider: auth.provider, uid: auth.uid)
    user.assign_attributes(
      email: auth.info.email,
      name: auth.info.name
    )
    user.save!
    user
  end

  def initials
    name.split.pluck(0).join.upcase
  end
end
