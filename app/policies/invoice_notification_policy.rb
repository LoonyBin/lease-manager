# frozen_string_literal: true

# Approving a send is an outward-facing action, so the outbox stays
# admin-only: every action falls through to ApplicationPolicy's admin check.
# The scope still resolves through accessible leases for consistency with the
# other finance policies.
class InvoiceNotificationPolicy < ApplicationPolicy
  def approve?
    update?
  end

  def cancel?
    update?
  end

  def retry?
    update?
  end

  def approve_all?
    update?
  end

  class Scope < Scope
    def resolve
      return scope.none unless user.admin?

      scope.where(invoice_id: InvoicePolicy::Scope.new(user, Invoice).resolve.select(:id))
    end
  end
end
