# frozen_string_literal: true

# Unhandled exceptions from the website and the Solid Queue worker are reported
# to Sentry, so that a release which boots but is broken behind the sign-in page
# tells somebody instead of waiting to be noticed.
#
# Inert until SENTRY_DSN is set on the host, and never enabled outside
# production. See lib/error_reporting/setup.rb for exactly what is and is not
# sent, and LOO-417 for the decision.
#
# Required explicitly rather than autoloaded: config.autoload_lib ignores this
# directory, because reaching for an autoloaded constant while the application
# is still initialising is not supported.
require Rails.root.join("lib/error_reporting/setup").to_s

ErrorReporting::Setup.install!
