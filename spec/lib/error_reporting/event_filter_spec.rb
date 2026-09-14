# frozen_string_literal: true

require "rails_helper"

RSpec.describe ErrorReporting::EventFilter do
  subject(:filter) { described_class.new }

  let(:configuration) { Sentry::Configuration.new }
  let(:event) { build_event(StandardError.new("could not bill alice@example.com")) }

  def build_event(exception)
    built = Sentry::ErrorEvent.new(configuration: configuration)
    built.add_exception_interface(exception, mechanism: Sentry::Mechanism.new(type: "spec", handled: false))
    built
  end

  def exception_values(filtered)
    filtered.exception.values.map(&:value)
  end

  def chained_exception
    raise "inner alice@example.com"
  rescue StandardError
    begin
      raise "outer bob@example.com"
    rescue StandardError => e
      e
    end
  end

  it "scrubs the exception message" do
    expect(exception_values(filter.call(event)).first).to include("[FILTERED_EMAIL]")
  end

  it "leaves no trace of the original in the exception message" do
    expect(exception_values(filter.call(event)).first).not_to include("alice@example.com")
  end

  it "scrubs every exception in a cause chain" do
    filtered = filter.call(build_event(chained_exception))

    expect(exception_values(filtered).join).not_to include("@example.com")
  end

  it "reports the whole cause chain, not only the outermost exception" do
    expect(exception_values(filter.call(build_event(chained_exception))).size).to be >= 2
  end

  it "scrubs the event message" do
    event.message = "failed for alice@example.com"

    expect(filter.call(event).message).to eq("failed for [FILTERED_EMAIL]")
  end

  it "scrubs strings nested in extra" do
    event.extra = { rows: [{ owner: "alice@example.com" }] }

    expect(filter.call(event).extra.dig(:rows, 0, :owner)).to eq("[FILTERED_EMAIL]")
  end

  it "scrubs strings nested in contexts, where Rails' error reporter puts its own" do
    event.contexts = { "rails.error" => { detail: "sent to bob@example.com" } }

    expect(filter.call(event).contexts.dig("rails.error", :detail)).to eq("sent to [FILTERED_EMAIL]")
  end

  it "scrubs tags" do
    event.tags = { recipient: "carol@example.com" }

    expect(filter.call(event).tags[:recipient]).to eq("[FILTERED_EMAIL]")
  end

  it "does not recurse for ever through a self-referencing context" do
    event.extra = { email: "alice@example.com" }.tap { |hash| hash[:self] = hash }

    expect { filter.call(event) }.not_to raise_error
  end

  context "with breadcrumbs" do
    let(:buffer) { Sentry::BreadcrumbBuffer.new(3) }
    let(:crumb) do
      Sentry::Breadcrumb.new(category: "spec", message: "notified alice@example.com",
                             data: { to: "bob@example.com" })
    end

    before do
      buffer.record(crumb)
      event.breadcrumbs = buffer
    end

    # The buffer preallocates its ring, so most of its slots are nil.
    it "scrubs the message and data without tripping over the buffer's empty slots", :aggregate_failures do
      scrubbed = filter.call(event).breadcrumbs.buffer.compact.first

      expect(scrubbed.message).to eq("notified [FILTERED_EMAIL]")
      expect(scrubbed.data[:to]).to eq("[FILTERED_EMAIL]")
    end
  end

  context "when scrubbing itself fails" do
    subject(:filter) { described_class.new(scrubber: exploding_scrubber) }

    let(:exploding_scrubber) do
      instance_double(ErrorReporting::MessageScrubber).tap do |double|
        allow(double).to receive(:call).and_raise(ArgumentError, "bad pattern")
      end
    end

    it "withholds the free text rather than sending it unscrubbed" do
      expect(exception_values(filter.call(event))).to all(eq(described_class::WITHHELD))
    end

    it "empties the structured context too, not just the message", :aggregate_failures do
      event.extra = { owner: "bob@example.com" }
      filtered = filter.call(event)

      expect(filtered.extra).to eq({})
      expect(filtered.contexts).to eq({})
      expect(filtered.breadcrumbs).to be_nil
    end

    # A withheld message still says the site is broken, which is the whole
    # reason for collecting errors. Dropping the event would not.
    it "still sends the report, with the exception class intact" do
      expect(filter.call(event).exception.values.first.type).to eq("StandardError")
    end

    it "never raises into the application that was reporting the error" do
      expect { filter.call(event) }.not_to raise_error
    end
  end
end
