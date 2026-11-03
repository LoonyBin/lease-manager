# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API token authentication" do
  let(:user) { create(:user, :admin) }
  let(:api_token) { create(:api_token, user: user) }
  let(:headers) { { "Authorization" => "Bearer #{api_token.plaintext_token}" } }

  describe "with a valid token" do
    it "serves JSON without a session" do
      get properties_path(format: :json), headers: headers
      expect(response).to have_http_status(:ok)
    end

    it "accepts the Token authorization scheme too" do
      get properties_path(format: :json), headers: { "Authorization" => "Token #{api_token.plaintext_token}" }
      expect(response).to have_http_status(:ok)
    end

    it "updates the token's last_used_at" do
      get properties_path(format: :json), headers: headers
      expect(api_token.reload.last_used_at).to be_present
    end

    it "records the token's user as whodunnit on mutations" do
      attributes = { name: "Villa", address: "1 API St", owner_id: create(:owner).id, capacity: 2, unit: "Rooms" }
      post properties_path(format: :json), params: { property: attributes }, headers: headers
      expect(Property.last.versions.last.whodunnit.to_i).to eq(user.id)
    end
  end

  describe "with a bad token" do
    it "rejects an unknown token" do
      get properties_path(format: :json), headers: { "Authorization" => "Bearer lmt_wrong" }
      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects a revoked token" do
      api_token.revoke!
      get properties_path(format: :json), headers: headers
      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects an expired token" do
      api_token.update!(expires_at: 1.hour.ago)
      get properties_path(format: :json), headers: headers
      expect(response).to have_http_status(:unauthorized)
    end

    it "does not fall back to a live session" do
      sign_in_as(user)
      get properties_path(format: :json), headers: { "Authorization" => "Bearer lmt_wrong" }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "without credentials" do
    it "returns 401 for JSON instead of redirecting" do
      get properties_path(format: :json)
      expect(response).to have_http_status(:unauthorized)
    end

    it "still redirects HTML requests to login" do
      get properties_path
      expect(response).to redirect_to(login_path)
    end
  end

  describe "browser session flow" do
    it "still serves HTML with a session" do
      sign_in_as(user)
      get properties_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "CSRF protection" do
    let(:attributes) { { name: "Villa", address: "1 St", owner_id: create(:owner).id, capacity: 2, unit: "Rooms" } }

    around do |example|
      original = ActionController::Base.allow_forgery_protection
      ActionController::Base.allow_forgery_protection = true
      example.run
    ensure
      ActionController::Base.allow_forgery_protection = original
    end

    it "allows token-authenticated mutations without a CSRF token" do
      post properties_path(format: :json), params: { property: attributes }, headers: headers
      expect(response).to have_http_status(:created)
    end

    it "still rejects session-style form posts without a CSRF token" do
      post properties_path, params: { property: attributes }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
