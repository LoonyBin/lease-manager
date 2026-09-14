# frozen_string_literal: true

module ErrorReporting
  # Rewrites the free text of an outgoing error report before it leaves the
  # server.
  #
  # An exception's message is the one part of a report that cannot simply be
  # switched off. Request bodies, cookies, query strings, IP addresses and
  # stack-frame variables are all turned off in ErrorReporting::Setup, but
  # without the message a report says only "something raised
  # ActiveRecord::StatementInvalid somewhere", which is not worth sending at
  # all. And messages quote values — in this application a value is a tenant's
  # email address, a payment amount or a person's name.
  #
  # So this removes what can be recognised by shape:
  #
  #   * email addresses, anywhere in the text;
  #   * the value in a Postgres constraint violation's detail line,
  #     `Key (email)=(bob@example.com) already exists`;
  #   * SQL string literals, when the text carries the statement that failed —
  #     Postgres quotes identifiers with " and literals with ', so the column
  #     and table names that make the error readable survive;
  #   * a value assigned to a name the application already refuses to write to
  #     its own logs (config.filter_parameters: passw, token, secret, ssn,
  #     cvv and the rest).
  #
  # What it cannot remove, and nobody should be told otherwise: a name, an
  # address or an amount sitting in prose. "Rent for Alice Whitfield could not
  # be calculated" has no shape to match on. This narrows the exposure; it does
  # not end it. That trade was put to the board owner in plain words and
  # accepted on LOO-417 — it is not a detail that was settled afterwards.
  class MessageScrubber
    FILTERED = "[FILTERED]"
    FILTERED_EMAIL = "[FILTERED_EMAIL]"

    EMAIL = /[A-Z0-9._%+'-]+@[A-Z0-9-]+(?:\.[A-Z0-9-]+)+/i

    # Postgres reports a unique or foreign key violation as
    #   DETAIL:  Key (email)=(bob@example.com) already exists.
    # The column name is the useful half and the value never is.
    PG_KEY_DETAIL = /(Key \([^()]*\)=\()[^()]*(\))/

    # Applied only when the text carries the statement itself, so that ordinary
    # prose containing an apostrophe is left alone.
    SQL_STATEMENT = /\b(?:SELECT|INSERT INTO|UPDATE|DELETE FROM)\b/i
    SQL_LITERAL = /'(?:[^']|'')*'/

    # A word containing a sensitive term, then an assignment, then its value.
    # The `:(?!:)` is load-bearing: without it "uninitialized constant
    # ApiToken::PermissionRegistry" is read as an assignment to `ApiToken` and
    # the half that names the missing constant is thrown away.
    ASSIGNMENT = /(\s*(?::(?!:)|=>|=)\s*)/
    VALUE = /(?:"[^"]*"|'[^']*'|\S+)/

    def initialize(sensitive_terms: self.class.default_sensitive_terms)
      @sensitive_assignment = self.class.sensitive_assignment_pattern(sensitive_terms)
    end

    # Reuses the list of parameter names the application already refuses to
    # log, rather than keeping a second list that can drift away from it.
    #
    # Returned as pattern fragments rather than as names, because the list does
    # not keep the shape it was written in. ActiveSupport::ParameterFilter
    # compiles config.filter_parameters *in place* the first time a request is
    # filtered: the twelve symbols in
    # config/initializers/filter_parameter_logging.rb are replaced by a single
    # combined Regexp. So reading this list before the first request and after
    # it are two different things, and a version of this method that understood
    # only symbols would go quietly dead the moment the process served anything
    # — matching nothing, raising nothing, and saying nothing about it.
    def self.default_sensitive_terms
      Rails.application.config.filter_parameters.filter_map do |filter|
        case filter
        when String, Symbol then Regexp.escape(filter.to_s)
        when Regexp then filter.source
        end
      end
    end

    # @param fragments [Array<String>] regexp sources, already escaped
    def self.sensitive_assignment_pattern(fragments)
      return /(?!)/ if fragments.empty?

      /(\b[\w.\[\]-]*(?:#{fragments.join('|')})[\w.\[\]-]*\b)#{ASSIGNMENT.source}#{VALUE.source}/i
    end

    # @param text [Object] returned unchanged unless it is a String
    # @return [Object]
    def call(text)
      return text unless text.is_a?(String)

      result = text
      result = result.gsub(SQL_LITERAL, "'#{FILTERED}'") if SQL_STATEMENT.match?(result)
      result = result.gsub(PG_KEY_DETAIL) { "#{Regexp.last_match(1)}#{FILTERED}#{Regexp.last_match(2)}" }
      result = result.gsub(@sensitive_assignment) { "#{Regexp.last_match(1)}#{Regexp.last_match(2)}#{FILTERED}" }
      result.gsub(EMAIL, FILTERED_EMAIL)
    end
  end
end
