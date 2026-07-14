# frozen_string_literal: true

class ApiToken < ApplicationRecord
  TOKEN_PREFIX = "lmt_"
  # not configurable: coarse last-used tracking; avoids one write per API request
  LAST_USED_THROTTLE = 1.minute

  belongs_to :user

  # ApplicationRecord already calls has_paper_trail (a second call raises),
  # so amend the inherited options: digests must never land in the audit
  # trail's object/object_changes.
  self.paper_trail_options = paper_trail_options.merge(skip: %w[token_digest])

  validates :name, presence: true
  validates :token_digest, presence: true, uniqueness: true

  scope :active, -> { where(revoked_at: nil).where("expires_at IS NULL OR expires_at > ?", Time.current) }

  # Populated only on the instance that generated the token; never persisted.
  attr_reader :plaintext_token

  before_validation :generate_token, on: :create

  def self.authenticate(plaintext)
    return if plaintext.blank?

    active.find_by(token_digest: digest(plaintext))
  end

  def self.digest(plaintext)
    OpenSSL::Digest::SHA256.hexdigest(plaintext)
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  def revoked?
    revoked_at.present?
  end

  def expired?
    expires_at.present? && expires_at.past?
  end

  # update_column: no callbacks, so API requests don't write audit versions.
  def touch_last_used
    return if last_used_at && last_used_at > LAST_USED_THROTTLE.ago

    update_column(:last_used_at, Time.current) # rubocop:disable Rails/SkipsModelValidations
  end

  private

  def generate_token
    @plaintext_token = "#{TOKEN_PREFIX}#{SecureRandom.base58(32)}"
    self.token_digest = self.class.digest(@plaintext_token)
  end
end
