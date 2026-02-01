# frozen_string_literal: true

class VersionPolicy < ApplicationPolicy
  def show?
    return admin? if record.item.nil?

    Pundit.policy(user, record.item).show?
  end

  def destroy?
    admin?
  end

  class Scope < Scope
    def resolve
      return scope.all if user.admin?

      # Filter versions to only include those the user can view
      viewable_versions
    end

    private

    def viewable_versions
      # Group item types and apply their respective policy scopes
      version_ids = []

      scope.distinct.pluck(:item_type).each do |item_type|
        klass = item_type.constantize
        policy_scope = Pundit.policy_scope(user, klass)
        item_ids = policy_scope.pluck(:id)
        version_ids += scope.where(item_type: item_type, item_id: item_ids).pluck(:id)
      end

      scope.where(id: version_ids)
    end
  end
end
