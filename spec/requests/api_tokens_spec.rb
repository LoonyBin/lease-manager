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

    it "creates a read-only token when that preset is chosen", :aggregate_failures do
      post api_tokens_path, params: { api_token: { name: "CI script", preset: "read_only" } }
      token = user.api_tokens.last
      expect(token.preset).to eq("read_only")
      expect(token.permissions).to eq(ApiToken::PermissionRegistry.read_preset)
    end

    it "expands the full preset to every grantable action", :aggregate_failures do
      post api_tokens_path, params: { api_token: { name: "CI script", preset: "full" } }
      token = user.api_tokens.last
      expect(token.preset).to eq("full")
      expect(token.permissions).to eq(ApiToken::PermissionRegistry.full_preset)
    end

    it "resolves a custom selection to the ticked, sanitized actions", :aggregate_failures do
      # Blank sentinel dropped; non-grantable entries (api_tokens#create,
      # bogus#nope) dropped by the registry intersection; custom stored as nil.
      submitted = ["", "invoices#index", "payments#create", "api_tokens#create", "bogus#nope"]
      post api_tokens_path, params: { api_token: { name: "narrow", preset: "custom", permissions: submitted } }
      token = user.api_tokens.last
      expect(token.preset).to be_nil
      expect(token.permissions).to eq(%w[invoices#index payments#create])
    end

    it "grants nothing when neither a preset nor permissions are submitted (fail-closed)" do
      post api_tokens_path, params: { api_token: { name: "CI script" } }
      expect(user.api_tokens.last.permissions).to be_empty
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
    it "renders the preset control and the immutability helper text", :aggregate_failures do
      get user_path(user)
      expect(response.body).to include('value="read_only"') # a preset radio
      expect(response.body).to include("Permissions are fixed once created")
    end

    # Scoped to the token's own row on purpose: "Read only" also appears in the
    # preset radio label (t("api_token_presets.read_only")), which renders
    # unconditionally, so a bare `include("Read only")` passes even when no token
    # is listed at all.
    it "shows each token's permission summary in the list" do
      create(:api_token, :read_only, user: user, name: "RO token")
      get user_path(user)
      row = Capybara.string(response.body).find("tr", text: "RO token")
      expect(row).to have_css("td", text: "Read only")
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
