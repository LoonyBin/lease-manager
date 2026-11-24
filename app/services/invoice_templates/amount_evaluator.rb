# frozen_string_literal: true

module InvoiceTemplates
  class EvaluationError < StandardError; end

  # Evaluates a line-item amount expression (arithmetic over Context variables)
  # safely via Dentaku. Amounts are rounded to currency precision.
  class AmountEvaluator
    AMOUNT_DECIMAL_PLACES = 2 # not configurable: currency precision for line-item amounts

    # Rounding precision accepted by ROUNDUP/ROUNDDOWN in an amount formula.
    # Amounts are rounded to currency precision, so a precision outside this
    # range is rejected instead of being applied.
    MAX_ROUNDING_PRECISION = 12

    # Dentaku functions that round, and whose precision we bound.
    ROUNDING_FUNCTIONS = %w[ROUNDUP ROUNDDOWN].freeze

    def initialize(variables)
      @variables = variables
      @calculator = self.class.calculator
    end

    def evaluate(expression)
      result = @calculator.evaluate!(expression, @variables)
      raise EvaluationError, "did not evaluate to a number" unless result.is_a?(Numeric)

      result.to_d.round(AMOUNT_DECIMAL_PLACES)
    rescue EvaluationError
      raise
    rescue StandardError => e
      raise EvaluationError, e.message
    end

    # Calculator with the rounding functions replaced by bounded versions.
    # Each evaluator gets its own calculator, so no state is shared between
    # expressions or between leases.
    def self.calculator
      calculator = Dentaku::Calculator.new
      ROUNDING_FUNCTIONS.each do |name|
        calculator.add_function(name, :numeric, bounded_rounding(name))
      end
      calculator
    end

    # Wraps Dentaku's own rounding function: the precision is checked before
    # any rounding happens, and everything else is left to Dentaku unchanged.
    def self.bounded_rounding(name)
      implementation = Dentaku::AST::Function.get(name).implementation

      lambda do |numeric, precision = 0|
        precision = Dentaku::NumericParser.ensure_numeric!(precision || 0)
        # The precision is compared as a number, before it is truncated to an
        # integer, so a precision written in scientific notation is rejected
        # like any other out-of-range value.
        unless precision.abs <= MAX_ROUNDING_PRECISION
          raise EvaluationError,
                "rounding precision must be between -#{MAX_ROUNDING_PRECISION} and #{MAX_ROUNDING_PRECISION}"
        end

        implementation.call(numeric, precision.to_i)
      end
    end
    private_class_method :bounded_rounding

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
