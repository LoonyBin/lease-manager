# frozen_string_literal: true

class PaymentPolicy < ApplicationPolicy
  def index?
    true
  end

  delegate :show?, :destroy?, to: :lease_policy, allow_nil: true

  def create?
    lease_policy&.show?
  end

  def new?
    admin? || user.owners.exists? || user.tenants.exists?
  end

  def update?
    admin? || owner_user?
  end

  private

  def lease_policy
    return unless record.lease

    @lease_policy ||= LeasePolicy.new(user, record.lease)
  end

  def owner_user?
    return false unless record.lease&.property_id

    user.owners.exists?(id: record.lease.property.owner_id)
  end

  class Scope < Scope
    def resolve
      return scope.all if user.admin?

      scope.where(lease_id: LeasePolicy::Scope.new(user, Lease).resolve.select(:id))
    end
  end
end
