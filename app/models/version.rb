# frozen_string_literal: true

class Version < PaperTrail::Version
  # Ransack allowlist — Version is a PaperTrail::Version, not an ApplicationRecord,
  # so it doesn't inherit the fail-closed base (#173); set the allowlist explicitly.
  # Keep in sync with app/views/versions/_search.html.haml, _sort.html.haml,
  # versions_controller.rb's default sort ("created_at desc"), and the history-sidebar
  # "view all" link (item_type_eq / item_id_eq). Deliberately omits object /
  # object_changes (full serialised record JSON) so they can't be substring-searched
  # via _cont on /versions. See #178.
  def self.ransackable_attributes(_auth_object = nil)
    %w[item_type item_id created_at event]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end
end
