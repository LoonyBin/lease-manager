# frozen_string_literal: true

class ApiToken
  # The set of "controller#action" permissions a token may be granted, derived
  # directly from Rails.application.routes.routes. There is no mapping table
  # between routes and grantable rows, and that is the point: a new controller
  # action is denied by construction — it is in no existing token's set until
  # someone ticks its box, and nothing has to decide what an "unrecognised"
  # action means (where failing open would be a silent hole).
  #
  # Two INDEPENDENT filters narrow the raw route list. They are separate on
  # purpose and must stay separate (see ApplicationController#enforce_token_permissions):
  #
  #   - NON_JSON_ACTIONS is best-effort noise reduction. new/edit render forms;
  #     a credential can never usefully invoke them. Getting this filter wrong
  #     costs a useless checkbox, never exposure — denial always comes from
  #     set-membership, never from this filter.
  #   - SECURITY_EXCLUDED_CONTROLLERS is a boundary, not noise reduction. These
  #     controllers must never be grantable. Getting it wrong is a real hole, so
  #     it is a hardcoded, reviewed list rather than anything derived.
  module PermissionRegistry
    # Security exclusion (NOT the best-effort JSON filter above):
    #   - sessions needs omniauth.auth / the browser session and is never
    #     token-usable, so it must not appear as a grantable row.
    #   - api_tokens is belt-and-braces behind the hard invariant in the
    #     controller guard: no token may ever manage tokens. The guard's
    #     unconditional early exit is what makes that unreachable; excluding it
    #     here just means no grant is ever offered in the first place.
    SECURITY_EXCLUDED_CONTROLLERS = %w[api_tokens sessions].freeze

    # Best-effort JSON filter. No new/edit action in this app has a JSON branch
    # (they exist to render HTML forms), so they are not capabilities a token
    # can use. Leaving one in by mistake only yields a checkbox that grants
    # access to an HTML response — noise, not a security boundary.
    NON_JSON_ACTIONS = %w[new edit].freeze

    class << self
      # Sorted, unique "controller#action" strings a token may be granted.
      def grantable_actions
        @grantable_actions ||= app_action_routes
                               .reject { |r| NON_JSON_ACTIONS.include?(r[:action]) }
                               .reject { |r| SECURITY_EXCLUDED_CONTROLLERS.include?(r[:controller]) }
                               .pluck(:id)
                               .uniq
                               .sort
      end

      # The grantable actions reachable over a safe (GET/HEAD) verb — the
      # "read only" preset. Reproduces exactly what the old verb-based
      # read_only scope allowed, so it is the read backfill for #172's tokens.
      def read_preset
        @read_preset ||= begin
          grantable = grantable_actions.to_set
          app_action_routes
            .select { |r| grantable.include?(r[:id]) && r[:read] }
            .pluck(:id)
            .uniq
            .sort
        end
      end

      # The full grantable set — the "full access" preset. Enumerated, not a
      # wildcard: a token granted "full" today does not silently gain a future
      # action, so denied-by-construction holds for full-access tokens too.
      def full_preset
        grantable_actions
      end

      # { "invoices" => %w[index show create update], ... } for the UI matrix,
      # controllers in sorted order, actions in sorted order.
      def grouped
        @grouped ||= grantable_actions.each_with_object({}) do |id, groups|
          controller, action = id.split("#")
          (groups[controller] ||= []) << action
        end
      end

      # Route tables are frozen at boot, so the derivations above are memoized.
      # Specs that inject routes call reset! to recompute.
      def reset!
        @grantable_actions = @read_preset = @grouped = nil
      end

      private

      # One pass over the route table, filtered to app controllers (the same
      # `klass <= ApplicationController` boundary the guard rests on, which also
      # drops framework controllers — turbo, action_mailbox, rails/* — without
      # naming them). Each entry carries whether it is reachable over GET/HEAD.
      def app_action_routes
        Rails.application.routes.routes.filter_map { |route| route_entry(route) }
      end

      def route_entry(route)
        controller = route.defaults[:controller]
        action = route.defaults[:action]
        return if controller.blank? || action.blank?

        klass = "#{controller}_controller".camelize.safe_constantize
        return unless klass && klass <= ApplicationController

        { id: "#{controller}##{action}", controller: controller, action: action, read: get_or_head?(route) }
      end

      def get_or_head?(route)
        verbs = route.verb.split("|")
        verbs.empty? || verbs.include?("GET") || verbs.include?("HEAD")
      end
    end
  end
end
