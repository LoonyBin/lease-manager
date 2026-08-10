# frozen_string_literal: true

class PaymentPolicy < ApplicationPolicy
  def index?
    true
  end

  # destroy? delegates to LeasePolicy#destroy? (admin || owner) — deliberately the
  # same bar as update?. Deletion is one of three sibling corrections (edit, reject,
  # delete); giving delete a stricter actor than the other two would be surprising.
  # See #196; tightening to admin-only is a one-line override of destroy? if wanted.
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
