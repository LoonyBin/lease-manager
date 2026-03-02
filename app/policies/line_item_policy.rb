# frozen_string_literal: true

class LineItemPolicy < ApplicationPolicy
  def show?
    return admin? if record.invoice.nil?

    Pundit.policy(user, record.invoice).show?
  end

  class Scope < Scope
    def resolve
      return scope.all if user.admin?

      scope.where(invoice_id: InvoicePolicy::Scope.new(user, Invoice).resolve.select(:id))
    end
  end
end
