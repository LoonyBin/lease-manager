# frozen_string_literal: true

class OwnerPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    admin? || associated_user? || tenant_of_owner?
  end

  def create?
    admin?
  end

  def update?
    admin? || associated_user?
  end

  def destroy?
    admin? || associated_user?
  end

  private

  def associated_user?
    return false unless record.persisted?

    user.owners.exists?(record.id)
  end

  def tenant_of_owner?
    return false unless record.persisted?

    user.tenants.joins(leases: :property).exists?(properties: { owner_id: record.id })
  end

  class Scope < Scope
    def resolve
      return scope.all if user.admin?

      scope.where(id: managed_ids).or(scope.where(id: leased_ids))
    end

    private

    def managed_ids
      user.owners.select(:id)
    end

    def leased_ids
      Owner.joins(properties: { leases: :tenant })
           .where(tenants: { id: user.tenants.select(:id) })
           .select(:id)
    end
  end
end
