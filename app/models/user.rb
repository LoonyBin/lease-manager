# frozen_string_literal: true

class User < ApplicationRecord
  has_many :user_associations, dependent: :destroy
  has_many :owners, through: :user_associations, source: :associable, source_type: "Owner"
  has_many :tenants, through: :user_associations, source: :associable, source_type: "Tenant"

  validates :uid, presence: true
  validates :provider, presence: true
  validates :uid, uniqueness: { scope: :provider }

  enum :role, { admin: 0, normal: 1 }, default: :normal

  def self.from_omniauth(auth)
    find_or_create_by(provider: auth.provider, uid: auth.uid) do |user|
      user.email = auth.info.email
      user.name = auth.info.name
    end
  end

  def initials
    name.split.pluck(0).join.upcase
  end
end
