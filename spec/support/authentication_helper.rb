# frozen_string_literal: true

module AuthenticationHelper
  def sign_in_as(user)
    OmniAuth.config.mock_auth[:developer] = OmniAuth::AuthHash.new(
      provider: user.provider,
      uid: user.uid,
      info: { email: user.email, name: user.name }
    )
    get "/auth/developer/callback"
  end

  def sign_in_admin
    @admin_user = create(:user, :admin)
    sign_in_as(@admin_user)
  end

  def sign_in_user
    @normal_user = create(:user)
    sign_in_as(@normal_user)
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelper, type: :request

  config.before(:each, type: :request) do
    OmniAuth.config.test_mode = true
  end

  config.after(:each, type: :request) do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:developer] = nil
  end
end
