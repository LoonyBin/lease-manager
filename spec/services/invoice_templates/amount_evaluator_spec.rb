# frozen_string_literal: true

require "rails_helper"

RSpec.describe InvoiceTemplates::AmountEvaluator do
  subject(:evaluator) { described_class.new(variables) }

  let(:variables) do
    { "rent" => BigDecimal("1000"), "r" => BigDecimal("1000"),
      "prorata" => 16.to_d / 31, "f" => 16.to_d / 31,
      "days_in_month" => 31, "n" => 31 }
  end

  describe "#evaluate" do
    it "evaluates literals" do
      expect(evaluator.evaluate("2500")).to eq(2500)
    end

    it "evaluates variables" do
      expect(evaluator.evaluate("rent")).to eq(1000)
    end

    it "supports arithmetic with parentheses" do
      expect(evaluator.evaluate("rent * (prorata - 1)")).to eq(BigDecimal("-483.87"))
    end

    it "supports short aliases" do
      expect(evaluator.evaluate("r * f")).to eq(BigDecimal("516.13"))
    end

    it "rounds results to two decimal places" do
      expect(evaluator.evaluate("1000 / 3")).to eq(BigDecimal("333.33"))
    end

    it "supports ROUND functions inside expressions" do
      expect(evaluator.evaluate("ROUNDDOWN(rent * f, 0)")).to eq(516)
    end

    it "is case-insensitive for variable names" do
      expect(evaluator.evaluate("RENT")).to eq(1000)
    end

    it "raises EvaluationError for unbound variables" do
      expect { evaluator.evaluate("rent * unknown_thing") }.to raise_error(InvoiceTemplates::EvaluationError)
    end

    it "raises EvaluationError for malformed expressions" do
      expect { evaluator.evaluate("rent * (") }.to raise_error(InvoiceTemplates::EvaluationError)
    end

    it "raises EvaluationError for division by zero" do
      expect { evaluator.evaluate("rent / 0") }.to raise_error(InvoiceTemplates::EvaluationError)
    end

    it "raises EvaluationError for non-numeric results" do
      expect { described_class.new("month_name" => "March").evaluate("month_name") }
        .to raise_error(InvoiceTemplates::EvaluationError)
    end
  end

  describe ".unknown_identifiers" do
    it "returns an empty array when all identifiers are known" do
      expect(described_class.unknown_identifiers("rent * (prorata - 1)")).to be_empty
    end

    it "ignores literals" do
      expect(described_class.unknown_identifiers("2500")).to be_empty
    end

    it "ignores built-in functions" do
      expect(described_class.unknown_identifiers("ROUND(rent / n, 2)")).to be_empty
    end

    it "lists identifiers that are not Context variables" do
      expect(described_class.unknown_identifiers("rent + maintenance_fee")).to eq(["maintenance_fee"])
    end

    it "raises EvaluationError for unparseable expressions" do
      expect { described_class.unknown_identifiers("rent +* 2") }
        .to raise_error(InvoiceTemplates::EvaluationError)
    end
  end
end
