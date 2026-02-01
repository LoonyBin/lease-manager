# frozen_string_literal: true

class Version < PaperTrail::Version
  def self.ransackable_attributes(_auth_object = nil)
    column_names
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end
end
