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
end
