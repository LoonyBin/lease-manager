# frozen_string_literal: true

class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  # Fail closed for Ransack: a model exposes nothing to search until it opts in
  # with an explicit allowlist. The old blanket default (every column, every
  # association) let /users filter on api_tokens.token_digest — see #173.
  # Searchable models override both methods below with a usage-derived allowlist.
  def self.ransackable_attributes(_auth_object = nil)
    []
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end

  has_paper_trail
end
