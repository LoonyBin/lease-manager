# frozen_string_literal: true

class ApiTokenPolicy < ApplicationPolicy
  def create?
    owner?
  end

  def destroy?
    owner?
  end

  private

  # Tokens are strictly self-managed; admins get no reach into others' tokens.
  def owner?
    record.user_id == user.id
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(user: user)
    end
  end
end
