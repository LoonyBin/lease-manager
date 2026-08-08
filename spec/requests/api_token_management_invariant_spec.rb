# frozen_string_literal: true

require "rails_helper"

# The hard invariant (decided 2026-08-08): no API token may ever reach
# ApiTokensController, even one whose stored permission set EXPLICITLY contains
# api_tokens#create/destroy.
#
# Granting the row directly — which the model allows, because it does not
# validate entries against the registry — is the whole point. A full-preset
# token would already 403 on api_tokens#* via the *permission* branch (the
# registry excludes api_tokens), and would still 403 with the early exit
# deleted. Only an explicitly-granted token proves the unconditional early exit,
# not the registry exclusion, is what refuses it — i.e. that this is an
# invariant, not a permission.
RSpec.describe "API token management invariant" do
  let(:user) { create(:user, :admin) }

  def headers_for(token)
    { "Authorization" => "Bearer #{token.plaintext_token}", "Accept" => "application/json" }
  end

  describe "a token explicitly granted api_tokens#create" do
    let(:token) { create(:api_token, :custom, user: user, permissions: %w[api_tokens#create]) }

    def mint_via(token)
      post api_tokens_path(format: :json),
           params: { api_token: { name: "escalated", preset: "full" } }, headers: headers_for(token)
    end

    # Side effect, not just status: a bare 403 assertion would pass even if the
    # record had already been written.
    it "mints no token and returns the gate's body", :aggregate_failures do
      token # instantiate the granting token before measuring, so only the POST counts
      expect { mint_via(token) }.not_to change(ApiToken, :count)
      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body["error"]).to eq(I18n.t("authorization.token_action_forbidden"))
    end
  end

  describe "a token explicitly granted api_tokens#destroy" do
    let(:token) { create(:api_token, :custom, user: user, permissions: %w[api_tokens#destroy]) }
    let(:target) { create(:api_token, user: user) }

    it "leaves the target unrevoked", :aggregate_failures do
      delete api_token_path(target, format: :json), headers: headers_for(token)
      expect(response).to have_http_status(:forbidden)
      expect(target.reload.revoked_at).to be_nil
    end
  end

  # Browser-session token management stays fully functional (the guard is gated
  # on token_request?). The authoritative create/revoke happy path lives in
  # spec/requests/api_tokens_spec.rb; this is the invariant's session half.
  describe "a logged-in browser session (no bearer token)" do
    before { sign_in_as(user) }

    it "can still create a token" do
      expect { post api_tokens_path, params: { api_token: { name: "browser", preset: "full" } } }
        .to change(user.api_tokens, :count).by(1)
    end
  end
end
