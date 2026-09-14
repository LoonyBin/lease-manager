# frozen_string_literal: true

require "rails_helper"

RSpec.describe ErrorReporting::MessageScrubber do
  subject(:scrubber) { described_class.new }

  def scrubbed(text)
    scrubber.call(text)
  end

  describe "#call" do
    it "leaves a message with nothing personal in it alone" do
      expect(scrubbed("undefined method 'total' for nil")).to eq("undefined method 'total' for nil")
    end

    it "returns a non-string untouched" do
      expect(scrubbed(nil)).to be_nil
    end

    it "removes an email address from anywhere in the text" do
      expect(scrubbed("550 5.1.1 <alice.whitfield@example.co.uk> does not exist"))
        .to eq("550 5.1.1 <[FILTERED_EMAIL]> does not exist")
    end

    it "leaves an apostrophe in ordinary prose alone" do
      expect(scrubbed("Couldn't find the owner's default template")).to eq("Couldn't find the owner's default template")
    end

    it "keeps the constant name in a namespaced NameError" do
      expect(scrubbed("uninitialized constant ApiToken::PermissionRegistry"))
        .to eq("uninitialized constant ApiToken::PermissionRegistry")
    end

    # The scrubber narrows what a report discloses; it does not end it, and a
    # spec that implied otherwise would be the most expensive kind of wrong.
    it "does not pretend to remove a name sitting in prose" do
      expect(scrubbed("rent for Alice Whitfield could not be calculated"))
        .to eq("rent for Alice Whitfield could not be calculated")
    end

    context "with a Postgres constraint violation" do
      let(:message) do
        <<~MESSAGE
          PG::UniqueViolation: ERROR:  duplicate key violates "index_tenants_on_reference"
          DETAIL:  Key (reference)=(WHITFIELD-2026-04) already exists.
        MESSAGE
      end

      it "removes the value and keeps the column and constraint names", :aggregate_failures do
        expect(scrubbed(message)).to include("Key (reference)=([FILTERED])")
        expect(scrubbed(message)).to include("index_tenants_on_reference")
        expect(scrubbed(message)).not_to include("WHITFIELD-2026-04")
      end
    end

    context "with the failing statement quoted in the message" do
      let(:message) do
        <<~MESSAGE
          PG::UndefinedColumn: ERROR:  column "tenants.nickname" does not exist
          LINE 1: SELECT "tenants".* FROM "tenants" WHERE "tenants"."surname" = 'Whitfield'
        MESSAGE
      end

      it "removes the SQL literals and keeps the identifiers that name the fault", :aggregate_failures do
        expect(scrubbed(message)).to include(%(WHERE "tenants"."surname" = '[FILTERED]'))
        expect(scrubbed(message)).to include(%(column "tenants.nickname" does not exist))
        expect(scrubbed(message)).not_to include("Whitfield")
      end
    end

    context "with a value assigned to a name the application refuses to log" do
      let(:message) { 'bad credentials {token: "sk_live_9f21", api_rate_limit: 300}' }

      it "removes the value and leaves the rest readable", :aggregate_failures do
        expect(scrubbed(message)).to include("token: [FILTERED]")
        expect(scrubbed(message)).to include("api_rate_limit: 300")
        expect(scrubbed(message)).not_to include("sk_live_9f21")
      end
    end
  end

  describe ".default_sensitive_terms" do
    # Asserted through the pattern rather than against the fragments, because
    # the fragments are one shape before the first request and another after.
    it "reuses the list the application already refuses to write to its logs" do
      pattern = described_class.sensitive_assignment_pattern(described_class.default_sensitive_terms)

      expect(%w[passw token secret ssn cvv].map { |name| "#{name}: value" }).to all(match(pattern))
    end

    it "understands both shapes the list can take, and drops what it cannot use" do
      allow(Rails.application.config).to receive(:filter_parameters).and_return([:passw, /(?i:otp)/, ->(*) {}])

      expect(described_class.default_sensitive_terms).to eq(["passw", "(?i:otp)"])
    end
  end

  # config.filter_parameters does not keep the shape it is written in:
  # ActiveSupport::ParameterFilter compiles it in place, symbols into one
  # combined Regexp, the first time the process filters a request. An earlier
  # version of this class read only the symbols, and so matched nothing at all
  # from the first request onwards — in production, that is always.
  describe "once a request has compiled config.filter_parameters", type: :request do
    it "still removes a value assigned to a filtered name" do
      get "/up"

      expect(scrubbed('token: "sk_live_9f21"')).to eq("token: [FILTERED]")
    end
  end

  describe ".sensitive_assignment_pattern" do
    it "matches nothing when there are no terms, rather than everything" do
      expect(described_class.sensitive_assignment_pattern([]).match?("password: hunter2")).to be(false)
    end
  end
end
