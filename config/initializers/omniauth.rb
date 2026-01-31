# frozen_string_literal: true

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :developer if Rails.env.development? || Rails.env.test?
end

OmniAuth.config.logger = Rails.logger

OmniAuth.config.allowed_request_methods = [:post, :get] if Rails.env.development? || Rails.env.test?
