# frozen_string_literal: true

class LeasePolicy < ApplicationPolicy
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
    return false unless record.persisted? && record.property_id

    user.owners.exists?(id: record.property.owner_id)
  end

  def tenant_user?
    return false unless record.persisted? && record.tenant_id

    user.tenants.exists?(id: record.tenant_id)
  end

  class Scope < Scope
    def resolve
      return scope.all if user.admin?

      scope.where(id: owned_ids).or(scope.where(id: tenant_ids))
    end

    private

    def owned_ids
      Lease.joins(property: :owner)
           .where(owners: { id: user.owners.select(:id) })
           .select(:id)
    end

    def tenant_ids
      Lease.where(tenant_id: user.tenants.select(:id)).select(:id)
    end
  end
end
