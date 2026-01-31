# frozen_string_literal: true

class PropertyPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    admin? || owner_user? || tenant_user?
  end

  def create?
    admin? || owner_user?
  end

  def update?
    admin? || owner_user?
  end

  def destroy?
    admin? || owner_user?
  end

  private

  def owner_user?
    return false unless record.persisted?

    user.owners.exists?(record.owner_id)
  end

  def tenant_user?
    return false unless record.persisted?

    user.tenants.joins(:leases).exists?(leases: { property_id: record.id })
  end

  class Scope < Scope
    def resolve
      return scope.all if user.admin?

      scope.where(id: owned_ids).or(scope.where(id: leased_ids))
    end

    private

    def owned_ids
      Property.where(owner_id: user.owners.select(:id)).select(:id)
    end

    def leased_ids
      Property.joins(:leases).where(leases: { tenant_id: user.tenants.select(:id) }).select(:id)
    end
  end
end
