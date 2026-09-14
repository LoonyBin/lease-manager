# frozen_string_literal: true

require_relative "message_scrubber"

module ErrorReporting
  # Sentry's `before_send` hook: the last thing that touches a report before it
  # is handed to the transport.
  #
  # It walks every place free text can reach an event — the exception messages,
  # the event message, the extra/contexts/tags hashes and the breadcrumb trail
  # — and runs each string through MessageScrubber.
  #
  # It fails closed. sentry-ruby calls `before_send` without a rescue of its
  # own, so an exception raised here would escape into whatever the application
  # was doing at the time; and a half-scrubbed event is worse than a useless
  # one, because the unscrubbed half still leaves the server. If anything goes
  # wrong the free text is replaced wholesale and the report is still sent:
  # the exception's class and its stack trace are enough to tell somebody that
  # the site is broken, which is the whole point of collecting errors at all.
  class EventFilter
    WITHHELD = "[withheld: scrubbing this report failed]"

    # Guards against a self-referencing hash in a report's context. Rails'
    # own payloads are shallow; something else's need not be.
    #
    # Anything below this is replaced wholesale rather than passed through:
    # returning the untouched subtree would send exactly the half-scrubbed
    # event this class exists to prevent. Replacing it also breaks the cycle,
    # which is what the depth limit was put here for.
    MAX_DEPTH = 8

    def self.call(event, hint = nil)
      new.call(event, hint)
    end

    def initialize(scrubber: MessageScrubber.new)
      @scrubber = scrubber
    end

    def call(event, _hint = nil)
      scrub_exceptions(event)
      event.message = scrub(event.message) if event.message
      event.extra = scrub_structure(event.extra)
      event.contexts = scrub_structure(event.contexts)
      event.tags = scrub_structure(event.tags)
      scrub_breadcrumbs(event)
      event
    rescue StandardError => e
      withhold(event, e)
    end

    private

    def scrub(text)
      @scrubber.call(text)
    end

    def scrub_exceptions(event)
      each_exception(event) { |single| single.value = scrub(single.value) }
    end

    def scrub_breadcrumbs(event)
      # BreadcrumbBuffer preallocates its ring, so the buffer holds nils until
      # it has filled up once.
      event.breadcrumbs&.buffer&.each do |crumb|
        next if crumb.nil?

        crumb.message = scrub(crumb.message) if crumb.message
        crumb.data = scrub_structure(crumb.data)
      end
    end

    def scrub_structure(value, depth: 0)
      return MessageScrubber::FILTERED if depth > MAX_DEPTH

      case value
      when String then scrub(value)
      when Hash then value.transform_values { |nested| scrub_structure(nested, depth: depth + 1) }
      when Array then value.map { |nested| scrub_structure(nested, depth: depth + 1) }
      else value
      end
    end

    def withhold(event, error)
      Rails.logger.error(
        "[error_reporting] scrubbing failed, withholding message text: #{error.class}: #{error.message}"
      )
      blank_free_text(event)
      event
    rescue StandardError
      # Nothing safe is left to send.
      nil
    end

    def blank_free_text(event)
      each_exception(event) { |single| single.value = WITHHELD }
      event.message = WITHHELD if event.message
      event.extra = {}
      event.contexts = {}
      event.tags = {}
      event.breadcrumbs = nil
    end

    # A report about a raised exception carries the whole cause chain, so there
    # is rarely only one message to deal with.
    def each_exception(event, &)
      return unless event.respond_to?(:exception)

      Array(event.exception&.values).each(&)
    end
  end
end
