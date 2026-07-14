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
    def self.unknown_identifiers(expression)
      dependencies = Dentaku::Calculator.new.dependencies(expression)
      dependencies.map(&:to_s) - Context::VARIABLE_NAMES
    rescue StandardError => e
      raise EvaluationError, e.message
    end
  end
end
