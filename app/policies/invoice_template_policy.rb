# frozen_string_literal: true

class InvoiceTemplatePolicy < ApplicationPolicy
  def show?
    return admin? if record.lease.nil?

    lease_policy.show?
  end

  def create?
    lease_policy&.update?
  end

  def update?
    lease_policy&.update?
  end

  def destroy?
    lease_policy&.update?
  end

  class Scope < Scope
    def resolve
      return scope.all if user.admin?

      scope.where(lease_id: LeasePolicy::Scope.new(user, Lease).resolve.select(:id))
    end
  end

  private

  def lease_policy
    return unless record.lease

    @lease_policy ||= LeasePolicy.new(user, record.lease)
  end
end
