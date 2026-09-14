# frozen_string_literal: true

require_relative "event_filter"
require_relative "message_scrubber"

module ErrorReporting
  # Builds the Sentry configuration for this application.
  #
  # This lives in lib/ rather than inline in config/initializers/sentry.rb so
  # that a spec can build a real Sentry::Configuration, apply it, and assert
  # what will and will not leave the server. Every one of those settings has a
  # safe default in sentry-ruby 7 today; the point of stating them anyway is
  # that a default is a promise the gem makes to itself, not to us, and a
  # future release changing one must fail a test rather than quietly start
  # posting request bodies to a third party.
  #
  # Nothing is sent unless SENTRY_DSN is set on the host AND the application is
  # running in production. Until someone with server access sets that variable
  # the integration is inert: the gems load, the middleware sees an
  # uninitialised client and passes every request straight through.
  module Setup
    ENABLED_ENVIRONMENTS = %w[production].freeze

    class << self
      def dsn
        ENV["SENTRY_DSN"].to_s.strip
      end

      def release
        ENV["SENTRY_RELEASE"].to_s.strip.presence
      end

      def enabled?
        dsn.present? && Rails.env.production?
      end

      def install!
        return unless enabled?

        ::Sentry.init { |config| configure(config) }
      end

      def configure(config)
        config.dsn = dsn
        config.release = release
        config.environment = Rails.env.to_s
        config.enabled_environments = ENABLED_ENVIRONMENTS
        config.before_send = scrubbing_filter

        configure_capture(config)
        configure_data_collection(config.data_collection)
        config
      end

      # Built once, here, rather than per event. MessageScrubber reads
      # config.filter_parameters, and ActiveSupport rewrites that list in place
      # the first time the process filters a request — so the honest moment to
      # read it is while the application is still starting up.
      def scrubbing_filter
        filter = EventFilter.new
        ->(event, hint) { filter.call(event, hint) }
      end

      def configure_capture(config)
        # Breadcrumbs are what turn "NoMethodError in production" into
        # something a person can act on: the controller and action, the
        # template that was rendering, the queries that ran. The payload keys
        # are allow-listed by sentry-rails and the parameter hash is dropped
        # entirely by the url_query_params setting below.
        config.breadcrumbs_logger = %i[active_support_logger]

        # Off by default in sentry-rails. Without it the Solid Queue worker's
        # own failures are invisible: a supervisor or dispatcher thread that
        # dies reports through Rails.error, not by raising into a job, so it
        # never reaches the ActiveJob integration. Part 1 of LOO-417 notices a
        # worker that has stopped heartbeating; this is what says why.
        config.rails.register_error_subscriber = true

        # Performance monitoring stays off. It would spend the free tier's
        # quota on transactions nobody is going to read, and a transaction
        # carries the same request data an error does.
        config.traces_sample_rate = nil

        config
      end

      # The privacy contract, spelled out rather than inherited.
      def configure_data_collection(data_collection)
        # No IP address, no signed-in user's id or email address.
        data_collection.user_info = false

        # No request or response bodies, in either direction. A form post to
        # this application is a tenant's name, address and bank details.
        data_collection.http_bodies = []

        # No cookies (the session cookie is a valid credential) and no headers
        # at all, in either direction.
        data_collection.cookies = false
        data_collection.http_headers.request.mode = :off
        data_collection.http_headers.response.mode = :off

        # No query string. The path still travels, so a report can say the
        # failure was on /leases/482/invoices/9911 — record identifiers, which
        # are what make a report actionable, and which mean nothing to anyone
        # without access to this application.
        data_collection.url_query_params = false

        # No bound values alongside the SQL in a database breadcrumb.
        data_collection.database_query_data = false

        # No queued job payloads.
        data_collection.queues = false

        # No local variables from each stack frame. This is the single largest
        # source of accidental disclosure in an exception reporter: every
        # method argument on the stack, which here is whole tenant and payment
        # records.
        data_collection.stack_frame_variables = false

        data_collection
      end
    end
  end
end
