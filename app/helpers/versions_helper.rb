# frozen_string_literal: true

module VersionsHelper
  def event_badge_class(event)
    case event
    when "create"
      "badge badge-success"
    when "update"
      "badge badge-info"
    when "destroy"
      "badge badge-error"
    else
      "badge badge-ghost"
    end
  end
end
