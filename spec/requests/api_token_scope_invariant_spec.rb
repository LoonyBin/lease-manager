# frozen_string_literal: true

require "rails_helper"

# Verb-based read_only scoping (ApplicationController#enforce_token_scope) is
# only as trustworthy as one claim: no GET/HEAD route reachable by a token
# holder mutates state. This spec walks the route table and fails if any app
# controller exposes a non-read action over a safe verb, so the invariant
# cannot silently drift (e.g. a future `get :recompute` or `via: :all`).
RSpec.describe "read_only token scope invariant" do
  # A global action-name allowlist, deliberately structural rather than a
  # per-controller allowlist: an allowlist keyed by controller would silently
  # skip any *new* controller — exactly the drift this guard exists to catch.
  let(:read_actions) { %w[index show new edit audit revenue outstanding taxes] }

  # sessions#create is the OAuth callback GET (routed via %i[get post]); it
  # writes a User but is never a token request (needs omniauth.auth from the
  # OmniAuth middleware), so enforce_token_scope never sees it. See docs/API.md.
  let(:known_exceptions) { %w[sessions#create] }

  # Non-read app actions reachable over a safe (GET/HEAD) verb. The structural
  # `klass <= ApplicationController` filter is exactly enforce_token_scope's own
  # boundary — it excludes framework controllers (turbo/native, action_mailbox,
  # rails/*) that would otherwise red-fail, without naming them one by one.
  #
  # What this cannot catch (so nobody over-trusts it): the read set is a global
  # action-name allowlist, so a *mutating* action named show/edit/audit would
  # pass here. The per-request enforcement and api_token_scopes_spec side-effect
  # assertions are the backstop for that.
  let(:offenders) do
    Rails.application.routes.routes.filter_map do |route|
      verbs = route.verb.split("|") # "GET|POST" => ["GET", "POST"]
      # Blank verb means mounts and `via: :all`; treat it as GET-matching so a
      # future `via: :all` route on an app controller cannot slip past.
      next unless verbs.empty? || verbs.include?("GET") || verbs.include?("HEAD")

      klass = "#{route.defaults[:controller]}_controller".camelize.safe_constantize
      next unless klass && klass <= ApplicationController

      id = "#{route.defaults[:controller]}##{route.defaults[:action]}"
      next if known_exceptions.include?(id)

      id unless read_actions.include?(route.defaults[:action])
    end
  end

  it "exposes no non-read action over a GET/HEAD verb on an app controller" do
    expect(offenders).to be_empty, "non-read GET/HEAD app routes: #{offenders.inspect}"
  end
end
