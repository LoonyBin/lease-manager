# frozen_string_literal: true

class TenantPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    admin? || associated_user? || owner_of_tenant?
  end

  def create?
    admin?
  end

  def update?
    admin? || associated_user?
  end

  def destroy?
    admin?
  end

  private

  def associated_user?
    return false unless record.persisted?

    user.tenants.exists?(record.id)
  end

  def owner_of_tenant?
    return false unless record.persisted?

    # User -> Owner -> Property -> Lease -> Tenant
    # Check if any of the user's owners have a property leased to this tenant
    user.owners.joins(properties: :leases).exists?(properties: { leases: { tenant_id: record.id } })
  end

  class Scope < Scope
    def resolve
      return scope.all if user.admin?

      scope.where(id: managed_ids).or(scope.where(id: leased_ids))
    end

    private

    def managed_ids
      user.tenants.select(:id)
    end

    def leased_ids
      Tenant.joins(leases: { property: :owner })
            .where(owners: { id: user.owners.select(:id) })
            .select(:id)
    end
  end
end
