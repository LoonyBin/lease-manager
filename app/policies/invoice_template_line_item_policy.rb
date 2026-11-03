# frozen_string_literal: true

class InvoiceTemplateLineItemPolicy < ApplicationPolicy
  def show?
    return admin? if record.invoice_template.nil?

    Pundit.policy(user, record.invoice_template).show?
  end

  class Scope < Scope
    def resolve
      return scope.all if user.admin?

      scope.where(invoice_template_id: InvoiceTemplatePolicy::Scope.new(user, InvoiceTemplate).resolve.select(:id))
    end
  end
end
