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

    it "creates a read_only token when that scope is chosen" do
      post api_tokens_path, params: { api_token: { name: "CI script", scope: "read_only" } }
      expect(user.api_tokens.last).to be_read_only
    end

    it "defaults to read_write when no scope is given" do
      post api_tokens_path, params: { api_token: { name: "CI script" } }
      expect(user.api_tokens.last).to be_read_write
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

  describe "GET /users/:id (token UI)" do
    it "renders the scope selector and the immutability helper text", :aggregate_failures do
      get user_path(user)
      expect(response.body).to include('value="read_only"')
      expect(response.body).to include("Scope is fixed once created")
    end

    it "shows each token's scope in the list" do
      create(:api_token, :read_only, user: user, name: "RO token")
      get user_path(user)
      expect(response.body).to include("Read only")
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
