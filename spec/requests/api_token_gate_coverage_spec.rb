# frozen_string_literal: true

require "rails_helper"

# Behavioural coverage of the enforcement gate: every grantable action must be
# refused for a token that was not granted it. It sweeps EVERY grantable action
# (not one sample per controller): a conditional
# `skip_before_action :enforce_token_permissions, only: :x` leaves the callback
# in the chain (so callback introspection can't see the hole) yet lets action
# :x through — only a per-action behavioural sweep catches it.
#
# This is NOT the successor to the retired route-walk invariant spec's read-drift
# guard (that a mutating action never becomes GET/HEAD-reachable and so never
# lands in read_preset). That guard is retargeted at
# ApiToken::PermissionRegistry.read_preset in
# spec/models/api_token/permission_registry_spec.rb.
RSpec.describe "API token permission gate coverage" do
  # (verb, path) for a grantable action, straight from the route table.
  # Synthetic "0" ids are fine: the gate halts in a before_action before any
  # record is looked up.
  def self.route_for(id)
    route = Rails.application.routes.routes.find { |r| "#{r.defaults[:controller]}##{r.defaults[:action]}" == id }
    verb = (route.verb.split("|") & %w[GET POST PATCH PUT DELETE]).first&.downcase || "get"
    [verb, route.format(route.required_parts.index_with { "0" })]
  end

  def bearer(token)
    { "Authorization" => "Bearer #{token.plaintext_token}", "Accept" => "application/json" }
  end

  ApiToken::PermissionRegistry.grantable_actions.each do |id|
    it "refuses #{id} for an empty-permission token, with the gate's own body", :aggregate_failures do
      # A FRESH token per request: the class-level rate-limit store buckets by
      # token digest and is not reset between examples, so reusing one token
      # would 429 after a handful of requests and mask the gate as a bug.
      verb, path = self.class.route_for(id)
      token = create(:api_token, :custom, permissions: [])
      public_send(verb, path, headers: bearer(token))
      expect(response).to have_http_status(:forbidden)
      # The gate's message, NOT Pundit's (authorization.not_authorized) — a bare
      # :forbidden would still pass if the gate were removed and Pundit refused.
      expect(response.parsed_body["error"]).to eq(I18n.t("authorization.token_action_forbidden"))
    end
  end

  # Floor. The sweep above derives its iteration set from the very registry it
  # tests, so an emptied registry would make it vacuously green (0 examples) and
  # a partial shrink would silently thin coverage with nothing noticing. Pin a
  # lower bound and a few load-bearing actions — including a mutating one
  # (versions#destroy) — so coverage can't be gutted without turning this red.
  it "sweeps a substantial, stable set of grantable actions", :aggregate_failures do
    grantable = ApiToken::PermissionRegistry.grantable_actions
    expect(grantable.size).to be >= 50
    expect(grantable).to include("invoices#index", "payments#create", "versions#destroy")
  end

  # Secondary, complementary to the sweep: localizes a regression to "callback
  # removed" vs "callback present but bypassed". The sweep is the one that must
  # pass; this alone would miss a conditional skip.
  it "keeps enforce_token_permissions in the controller callback chain" do
    filters = ApplicationController._process_action_callbacks.map(&:filter)
    expect(filters).to include(:enforce_token_permissions)
  end
end
