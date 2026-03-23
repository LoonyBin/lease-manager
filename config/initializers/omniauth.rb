# frozen_string_literal: true

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :developer if Rails.env.local?
  if Rails.application.credentials.dig(:google, :client_id).present?
    provider :google_oauth2,
             Rails.application.credentials.dig(:google, :client_id),
             Rails.application.credentials.dig(:google, :client_secret), {
               scope: "email, profile",
               prompt: "select_account"
             }
  end
end

OmniAuth.config.logger = Rails.logger
OmniAuth.config.allowed_request_methods = %i[post]
