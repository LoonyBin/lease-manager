# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include Pundit::Authorization
  include JsonResponses

  # Rate-limit counters live in a dedicated in-process store, which is
  # accurate for this deployment: Puma runs one process (no workers) on a
  # single node, and Rails.cache is unsuitable anyway (:null_store in test,
  # per-process memory in production). If the app ever runs multiple
  # processes, swap this for a shared store (e.g. solid_cache) so counters
  # stay global.
  API_RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new

  # Registered before the other callbacks: require_login halts the chain with
  # a 401 on invalid, revoked, or expired tokens, so the limiter must run
  # first to throttle those requests too (and to skip the token lookup that
  # set_paper_trail_whodunnit triggers via current_user when throttled).
  # Keyed by the digest of the presented token, shared across controllers.
  rate_limit to: Rails.configuration.x.api_rate_limit.limit,
             within: Rails.configuration.x.api_rate_limit.period,
             by: -> { ApiToken.digest(presented_token.to_s) },
             with: -> { render json: { error: "Rate limit exceeded" }, status: :too_many_requests },
             store: API_RATE_LIMIT_STORE,
             scope: "api",
             if: :token_request?

  before_action :set_paper_trail_whodunnit
  before_action :require_login
  before_action :enforce_token_scope, if: :token_request?
  after_action :verify_pundit_authorization

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Browsers cannot attach an Authorization header to cross-site form posts,
  # and token requests never fall back to the session (see #current_user),
  # so CSRF protection is unnecessary for them. Session requests keep it.
  skip_before_action :verify_authenticity_token, if: :token_request?

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  helper_method :current_user, :logged_in?

  private

  def current_user
    @current_user ||= token_request? ? user_from_token : user_from_session
  end

  def user_from_session
    User.find_by(id: session[:user_id]) if session[:user_id]
  end

  # When an Authorization header is present there is no session fallback: an
  # invalid, revoked, or expired token is a 401 even with a live session.
  def user_from_token
    current_api_token&.tap(&:touch_last_used)&.user
  end

  # Memoized so require_login and enforce_token_scope share one lookup.
  # `defined?` (not ||=) caches a nil result too — an absent/invalid token is
  # looked up once, not on every predicate.
  def current_api_token
    return @current_api_token if defined?(@current_api_token)

    @current_api_token = ApiToken.authenticate(presented_token)
  end

  # The token parsed from the Authorization header (nil when absent or
  # malformed). The rate limiter keys off this same value, so Token/Bearer
  # scheme and whitespace variants of one credential share a single bucket.
  def presented_token
    ActionController::HttpAuthentication::Token.token_and_options(request)&.first
  end

  def token_request?
    request.authorization.present?
  end

  def logged_in?
    current_user.present?
  end

  def require_login
    return if logged_in?

    if request.format.json?
      render json: { error: "Unauthorized" }, status: :unauthorized
    else
      redirect_to login_path
    end
  end

  # Credential-level guard: a read_only token may make only safe requests.
  # This rests on the invariant that no GET/HEAD route reachable by a token
  # holder mutates state. Two known writes-on-a-safe-verb, both out of reach
  # from a read_only token, keep that invariant honest:
  #   - sessions#create (OAuth callback GET; needs omniauth.auth, never a token request)
  #   - ApiToken#touch_last_used (benign last_used_at bump on every authed GET)
  # A route-walk spec (spec/requests/api_token_scope_invariant_spec.rb) guards
  # this against future drift. Halting here in a before_action means the
  # after_action verify_pundit_authorization never runs, so a blocked write
  # raises no spurious "authorize was not called" error.
  def enforce_token_scope
    return unless current_api_token&.read_only?
    return if request.get? || request.head?

    render json: { error: t("authorization.read_only_token") }, status: :forbidden
  end

  def verify_pundit_authorization
    if action_name == "index"
      verify_policy_scoped
    else
      verify_authorized
    end
  end

  def user_not_authorized
    if request.format.json?
      render json: { error: t("authorization.not_authorized") }, status: :forbidden
    else
      redirect_back_or_to root_path, alert: t("authorization.not_authorized")
    end
  end
end
