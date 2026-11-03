# frozen_string_literal: true

module InvoiceTemplates
  class EvaluationError < StandardError; end

  # Evaluates a line-item amount expression (arithmetic over Context variables)
  # safely via Dentaku. Amounts are rounded to currency precision.
  class AmountEvaluator
    AMOUNT_DECIMAL_PLACES = 2 # not configurable: currency precision for line-item amounts

    def initialize(variables)
      @variables = variables
    end

    def evaluate(expression)
      result = Dentaku::Calculator.new.evaluate!(expression, @variables)
      raise EvaluationError, "did not evaluate to a number" unless result.is_a?(Numeric)

      result.to_d.round(AMOUNT_DECIMAL_PLACES)
    rescue EvaluationError
      raise
    rescue StandardError => e
      raise EvaluationError, e.message
    end

    # Identifiers referenced by the expression that are not Context variables.
    # Raises EvaluationError when the expression cannot be parsed.
    #
    # Uses `identifiers` rather than `dependencies`: since dentaku 4.0 the
    # latter prunes identifiers it can prove are never read (the untaken branch
    # of a statically resolvable CASE, the short-circuited side of AND/OR), so
    # a typo hiding on a dead branch would validate clean and only fail later
    # at invoice generation, when a different lease makes that branch live.
    def self.unknown_identifiers(expression)
      identifiers = Dentaku::Calculator.new.identifiers(expression)
      identifiers.map(&:to_s) - Context::VARIABLE_NAMES
    rescue StandardError => e
      raise EvaluationError, e.message
    end
  end
end
