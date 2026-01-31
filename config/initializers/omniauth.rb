# frozen_string_literal: true

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :developer if Rails.env.local?
end

OmniAuth.config.logger = Rails.logger

OmniAuth.config.allowed_request_methods = %i[post get] if Rails.env.local?
