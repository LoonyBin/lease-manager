# frozen_string_literal: true

class VersionPolicy < ApplicationPolicy
  # PaperTrail tracks every ApplicationRecord, so a model can end up in the
  # audit trail before it has a policy of its own. Pundit.policy returns nil in
  # that case; fall back to admin-only rather than raising NoMethodError and
  # turning the whole page into a 500.
  def show?
    return admin? if record.item.nil?

    item_policy = Pundit.policy(user, record.item)
    return admin? if item_policy.nil?

    item_policy.show?
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
        # A version outlives its model: the class may since have been renamed or
        # dropped, and a tracked model may have no policy scope. Skip those
        # instead of raising and taking down the index.
        klass = item_type.safe_constantize
        next if klass.nil?

        policy_scope = Pundit.policy_scope(user, klass)
        next if policy_scope.nil?

        item_ids = policy_scope.pluck(:id)
        version_ids += scope.where(item_type: item_type, item_id: item_ids).pluck(:id)
      end

      scope.where(id: version_ids)
    end
  end
end
