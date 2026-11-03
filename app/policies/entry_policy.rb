# frozen_string_literal: true

# Entry has no controller, but PaperTrail tracks it and VersionPolicy delegates
# to the item's own policy, so the audit trail needs one. A ledger entry is
# visible to whoever can see the lease it belongs to.
class EntryPolicy < ApplicationPolicy
  def show?
    return admin? if record.lease.nil?

    Pundit.policy(user, record.lease).show?
  end

  class Scope < Scope
    def resolve
      return scope.all if user.admin?

      scope.where(lease_id: LeasePolicy::Scope.new(user, Lease).resolve.select(:id))
    end
  end
end
