# frozen_string_literal: true

class PaymentPolicy < ApplicationPolicy
  def index?
    true
  end

  delegate :show?, :update?, :destroy?, to: :lease_policy, allow_nil: true

  def create?
    lease_policy&.update?
  end

  def new?
    admin? || user.owners.exists?
  end

  private

  def lease_policy
    return unless record.lease

    @lease_policy ||= LeasePolicy.new(user, record.lease)
  end

  class Scope < Scope
    def resolve
      return scope.all if user.admin?

      scope.where(lease_id: LeasePolicy::Scope.new(user, Lease).resolve.select(:id))
    end
  end
end
