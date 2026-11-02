# frozen_string_literal: true

require "rails_helper"

RSpec.describe ErrorReporting::Setup do
  # Syntactically valid and pointing at nothing. The end-to-end example below
  # swaps in Sentry's dummy transport, which is what keeps the event here.
  let(:fake_dsn) { "https://publickey@o0.ingest.sentry.io/0" }

  around do |example|
    previous = ENV.fetch("SENTRY_DSN", nil)
    example.run
  ensure
    previous.nil? ? ENV.delete("SENTRY_DSN") : ENV["SENTRY_DSN"] = previous
  end

  def in_production
    allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))
  end

  describe ".enabled?" do
    it "is false in production when no DSN is set, so the integration stays inert" do
      in_production
      ENV.delete("SENTRY_DSN")

      expect(described_class).not_to be_enabled
    end

    it "is false when SENTRY_DSN holds nothing but whitespace" do
      in_production
      ENV["SENTRY_DSN"] = "   "

      expect(described_class).not_to be_enabled
    end

    it "is false outside production even with a DSN set" do
      ENV["SENTRY_DSN"] = fake_dsn

      expect(described_class).not_to be_enabled
    end

    it "is true in production with a DSN set" do
      in_production
      ENV["SENTRY_DSN"] = fake_dsn

      expect(described_class).to be_enabled
    end
  end

  describe ".install!" do
    it "does not initialise Sentry when it is not enabled" do
      ENV.delete("SENTRY_DSN")
      described_class.install!

      expect(Sentry).not_to be_initialized
    end
  end

  describe ".configure" do
    subject(:configuration) do
      ENV["SENTRY_DSN"] = fake_dsn
      described_class.configure(Sentry::Configuration.new)
    end

    it "sends only in production" do
      expect(configuration.enabled_environments).to eq(["production"])
    end

    it "reads the DSN from the environment" do
      expect(configuration.dsn.to_s).to eq(fake_dsn)
    end

    it "installs the scrubbing filter" do
      expect(configuration.before_send).to respond_to(:call)
    end

    it "subscribes to Rails' error reporter, so Solid Queue thread failures are seen" do
      expect(configuration.rails.register_error_subscriber).to be(true)
    end

    it "leaves performance monitoring off" do
      expect(configuration.traces_sample_rate).to be_nil
    end

    it "keeps the breadcrumb trail that makes a report actionable" do
      expect(configuration.breadcrumbs_logger).to eq([:active_support_logger])
    end

    # These are the promises made to the board owner on LOO-417 about what
    # leaves the server. Each happens to be sentry-ruby 7's own default; the
    # examples are here so that a release changing one fails the build instead
    # of quietly widening what this application discloses.
    describe "what does not leave the server" do
      it "sends no user identity or IP address" do
        expect(configuration.data_collection.user_info).to be(false)
      end

      it "sends no request or response body" do
        expect(configuration.data_collection.http_bodies).to eq([])
      end

      it "sends no cookies" do
        expect(configuration.data_collection.cookies.mode).to eq(:off)
      end

      it "sends no request headers" do
        expect(configuration.data_collection.http_headers.request.mode).to eq(:off)
      end

      it "sends no response headers" do
        expect(configuration.data_collection.http_headers.response.mode).to eq(:off)
      end

      it "sends no query string" do
        expect(configuration.data_collection.url_query_params.mode).to eq(:off)
      end

      it "sends no bound values alongside a query" do
        expect(configuration.data_collection.database_query_data).to be(false)
      end

      it "sends no queued job payloads" do
        expect(configuration.data_collection.queues).to be(false)
      end

      it "sends no local variables from the stack" do
        expect(configuration.data_collection.collect_stack_frame_variables?).to be(false)
      end
    end
  end

  describe "a real capture, end to end" do
    let(:transport) { Sentry.get_current_client.transport }
    let(:single_exception) { transport.events.last.exception.values.first }

    before do
      ENV["SENTRY_DSN"] = fake_dsn
      Sentry.init do |config|
        described_class.configure(config)
        # The configuration under test refuses to send outside production, and
        # this suite is not production. Say so, then take the transport away.
        config.environment = "production"
        config.background_worker_threads = 0
        config.transport.transport_class = Sentry::DummyTransport
      end
      Sentry.capture_exception(build_argument_error)
    end

    after { Sentry.close }

    def build_argument_error
      raise ArgumentError, "bad amount for bob@example.com"
    rescue ArgumentError => e
      e
    end

    it "scrubs the message of an exception captured through the real client" do
      expect(single_exception.value).to include("bad amount for [FILTERED_EMAIL]")
    end

    it "leaves no trace of the address in what the transport was handed" do
      expect(single_exception.value).not_to include("bob@example.com")
    end

    it "keeps the exception class, which is half of what identifies the fault" do
      expect(single_exception.type).to eq("ArgumentError")
    end

    it "keeps the stack trace, which is the other half" do
      expect(single_exception.stacktrace.frames).not_to be_empty
    end
  end
end
