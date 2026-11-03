# frozen_string_literal: true

class UserPolicy < ApplicationPolicy
  # Everyone may view their own profile (it hosts the API token UI).
  def show?
    admin? || record == user
  end
end
