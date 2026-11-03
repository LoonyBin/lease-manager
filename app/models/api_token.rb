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

  # The two labels a `preset` may carry. Display-only: rendered as the token's
  # creation-time intent ("Full access" / "Read only") and NEVER consulted for
  # enforcement — that is always set membership in `permissions`. A "custom"
  # selection is normalised to nil by ApiTokensController, so it never reaches
  # here. See PermissionRegistry and docs/API.md.
  PRESETS = %w[read_only full].freeze

  # A token's capability is the set of "controller#action" strings it may
  # invoke, checked in front of Pundit by
  # ApplicationController#enforce_token_permissions. permits? is the whole
  # contract the guard needs; Pundit still decides what the *user* may do to a
  # *record* afterwards, so a grant can only ever narrow, never widen.
  #
  # permissions and preset are fixed at creation. There is no update route
  # (resources :api_tokens, only: %i[create destroy]); attr_readonly keeps them
  # immutable even if one is ever added, so a token can never widen its own
  # capability in place — you revoke and re-issue. attr_readonly blocks
  # post-creation writes only, so creation-time assignment still works.
  attr_readonly :permissions, :preset

  validates :name, presence: true
  validates :token_digest, presence: true, uniqueness: true
  validates :preset, inclusion: { in: PRESETS }, allow_nil: true
  validate :permissions_is_a_list_of_strings

  # Only on create: permissions are attr_readonly, so re-assigning them on a
  # later save (e.g. revoke! writing revoked_at) would raise
  # ReadonlyAttributeError. They can never change after creation, so there is
  # nothing to normalize on update anyway. Mirrors generate_token below.
  before_validation :normalize_permissions, on: :create

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

  # The single question the request-level guard asks. Deliberately a plain set
  # lookup: no registry knowledge, so a grant for an action that no longer
  # routes simply never matches (fails closed).
  def permits?(controller_action)
    permissions.include?(controller_action)
  end

  # Granted actions that no longer correspond to a routable, grantable action —
  # e.g. a route renamed after the token was minted. Under attr_readonly these
  # cannot be repaired in place, so the token UI surfaces them as a warning.
  def orphaned_grants
    permissions - PermissionRegistry.grantable_actions
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

  # Store a canonical form: duplicates collapsed, deterministic order (which
  # also keeps the audit trail's before/after diffs stable). Sorting is skipped
  # unless every entry is a String, so a malformed value reaches the validation
  # below as an error rather than raising here on a mixed-type comparison.
  def normalize_permissions
    return unless permissions.is_a?(Array)

    self.permissions = permissions.uniq
    self.permissions = permissions.sort if permissions.all?(String)
  end

  # Entries are opaque "controller#action" strings. Deliberately NOT validated
  # against the registry: a stale entry can never match a route, so it is
  # harmless — and accepting non-registry entries is what makes the
  # "a token may never manage tokens" invariant testable (a token can be
  # created carrying api_tokens#create, and the guard must still refuse it).
  def permissions_is_a_list_of_strings
    return if permissions.is_a?(Array) && permissions.all?(String)

    errors.add(:permissions, "must be a list of \"controller#action\" strings")
  end
end
