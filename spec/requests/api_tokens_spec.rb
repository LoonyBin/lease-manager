# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ApiTokens" do
  let(:user) { create(:user) }

  before { sign_in_as(user) }

  describe "POST /api_tokens" do
    it "creates a token for the current user" do
      expect do
        post api_tokens_path, params: { api_token: { name: "CI script" } }
      end.to change(user.api_tokens, :count).by(1)
    end

    it "redirects to the profile" do
      post api_tokens_path, params: { api_token: { name: "CI script" } }
      expect(response).to redirect_to(user_path(user))
    end

    it "shows the plaintext once on the profile" do
      post api_tokens_path, params: { api_token: { name: "CI script" } }
      follow_redirect!
      expect(response.body).to match(/lmt_\w+/)
    end

    it "does not show the plaintext on later renders" do
      post api_tokens_path, params: { api_token: { name: "CI script" } }
      follow_redirect!
      get user_path(user)
      expect(response.body).not_to match(/lmt_\w+/)
    end

    it "does not create a token without a name" do
      expect do
        post api_tokens_path, params: { api_token: { name: "" } }
      end.not_to change(ApiToken, :count)
    end

    it "redirects with an alert without a name" do
      post api_tokens_path, params: { api_token: { name: "" } }
      expect(flash[:alert]).to be_present
    end
  end

  describe "DELETE /api_tokens/:id" do
    it "revokes the token" do
      token = create(:api_token, user: user)
      delete api_token_path(token)
      expect(token.reload.revoked?).to be(true)
    end

    it "keeps the row for the audit trail" do
      token = create(:api_token, user: user)
      expect { delete api_token_path(token) }.not_to change(ApiToken, :count)
    end

    it "returns 404 for another user's token" do
      token = create(:api_token)
      delete api_token_path(token)
      expect(response).to have_http_status(:not_found)
    end
  end
end
