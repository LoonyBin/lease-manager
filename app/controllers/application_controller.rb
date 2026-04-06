# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include Pundit::Authorization

  before_action :set_paper_trail_whodunnit
  before_action :require_login
  after_action :verify_pundit_authorization

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  helper_method :current_user, :logged_in?, :safe_return_to

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def logged_in?
    current_user.present?
  end

  def require_login
    redirect_to login_path unless logged_in?
  end

  def verify_pundit_authorization
    if action_name == "index"
      verify_policy_scoped
    else
      verify_authorized
    end
  end

  def user_not_authorized
    redirect_back_or_to root_path, alert: t("authorization.not_authorized")
  end

  def safe_return_to(url, fallback:)
    return fallback if url.blank?

    uri = URI.parse(url)
    uri.host.nil? ? url : fallback
  rescue URI::InvalidURIError
    fallback
  end
end
