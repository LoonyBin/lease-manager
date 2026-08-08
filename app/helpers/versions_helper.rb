# frozen_string_literal: true

module VersionsHelper
  EVENT_BADGES = {
    create: "badge-success",
    update: "badge-info",
    destroy: "badge-error"
  }.freeze

  def event_badge(event)
    modifier = EVENT_BADGES.fetch(event.to_sym, "badge-ghost")
    tag.span(event.humanize, class: token_list("badge", modifier))
  end

  # An audited value can be an array (e.g. an ApiToken's `permissions` grant of
  # dozens of "controller#action" strings). PaperTrail stores a jsonb column
  # double-encoded — a JSON string inside the JSON object_changes — so such a
  # value arrives here as a string like %(["invoices#index", ...]); decode that
  # back to an array first. Render arrays as a list so a change is legible
  # instead of one blob; scalars render as-is.
  def audit_change_value(value)
    value = decode_audit_array(value)
    return value unless value.is_a?(Array)

    tag.ul(class: "list-disc list-inside") do
      safe_join(value.map { |item| tag.li(item) })
    end
  end

  private

  def decode_audit_array(value)
    return value unless value.is_a?(String) && value.start_with?("[")

    parsed = JSON.parse(value)
    parsed.is_a?(Array) ? parsed : value
  rescue JSON::ParserError
    value
  end
end
