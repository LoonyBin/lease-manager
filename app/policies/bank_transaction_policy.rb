# frozen_string_literal: true

class BankTransactionPolicy < ApplicationPolicy
  def confirm?
    update?
  end

  def reject?
    update?
  end

  def rematch?
    update?
  end
end
