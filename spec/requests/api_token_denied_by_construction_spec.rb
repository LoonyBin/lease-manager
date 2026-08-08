# frozen_string_literal: true

require "rails_helper"

# Proves "denied by construction" (acceptance criterion): a brand-new controller
# action, never seen by any token, cannot be invoked by an existing token until
# its box is ticked. The behavioural analog of the retired spec's `get :recompute`
# injection.
class DeniedByConstructionProbeController < ApplicationController
  skip_after_action :verify_pundit_authorization

  # Records whether the action body actually ran, so a blocked request can be
  # proven not to have executed it — not merely to have returned 403.
  cattr_accessor :ran, default: false

  def recompute
    self.class.ran = true
    head :ok
  end
end

RSpec.describe "denied by construction" do
  let(:user) { create(:user, :admin) }
  # An explicit permission literal (not a preset): a full/read preset resolves
  # from the registry, which now knows the probe, so only a literal guarantees
  # the token does NOT already carry the new action.
  let(:token) { create(:api_token, :custom, user: user, permissions: %w[invoices#index]) }

  def probe_request
    get "/denied_by_construction_probe",
        headers: { "Authorization" => "Bearer #{token.plaintext_token}", "Accept" => "application/json" }
  end

  around do |example|
    DeniedByConstructionProbeController.ran = false
    # Append a route without clearing the app's real routes, then recompute the
    # memoized registry so it sees the new action.
    Rails.application.routes.disable_clear_and_finalize = true
    Rails.application.routes.draw do
      get "denied_by_construction_probe", to: "denied_by_construction_probe#recompute"
    end
    ApiToken::PermissionRegistry.reset!

    example.run
  ensure
    Rails.application.routes.disable_clear_and_finalize = false
    Rails.application.reload_routes!
    ApiToken::PermissionRegistry.reset!
  end

  it "refuses the new action for an existing token and runs no side effect", :aggregate_failures do
    probe_request
    expect(response).to have_http_status(:forbidden)
    expect(response.parsed_body["error"]).to eq(I18n.t("authorization.token_action_forbidden"))
    expect(DeniedByConstructionProbeController.ran).to be(false)
  end

  it "would grant the probe once its box is ticked (so the denial is a real 'not in the set', not a 404)" do
    # The action IS routable and grantable now; the token above simply wasn't
    # granted it. Proves the refusal is set-membership, not an unrouteable path.
    expect(ApiToken::PermissionRegistry.grantable_actions).to include("denied_by_construction_probe#recompute")
  end
end
