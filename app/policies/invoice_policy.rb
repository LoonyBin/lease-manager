# frozen_string_literal: true

class InvoicePolicy < ApplicationPolicy
  def index?
    true
  end

  delegate :show?, :update?, :destroy?, to: :lease_policy, allow_nil: true

  def create?
    lease_policy&.update?
  end

  # The JSON draft preview: bound to this lease, unlike +new?+, and closed to
  # tenants because it shows charges that are not billed yet.
  def preview?
    create?
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
