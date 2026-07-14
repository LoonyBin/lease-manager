# frozen_string_literal: true

module InvoiceTemplates
  # Substitutes {placeholder} tokens in template text with Context variables,
  # e.g. "Rent for {month_name} {year}" => "Rent for March 2026".
  class TextRenderer
    PLACEHOLDER_PATTERN = /\{(\w+)\}/

    def initialize(variables)
      @variables = variables
    end

    def render(text)
      text.to_s.gsub(PLACEHOLDER_PATTERN) do |token|
        name = Regexp.last_match(1).downcase
        @variables.key?(name) ? format_value(@variables[name]) : token
      end
    end

    # Placeholder names in the text that are not Context variables.
    def self.unknown_placeholders(text)
      text.to_s.scan(PLACEHOLDER_PATTERN).flatten.map(&:downcase).uniq - Context::VARIABLE_NAMES
    end

    private

    def format_value(value)
      case value
      when Date
        value.strftime("%B %-d, %Y")
      when BigDecimal, Float
        (value % 1).zero? ? value.to_i.to_s : value.to_f.to_s
      else
        value.to_s
      end
    end
  end
end
