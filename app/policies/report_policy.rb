# frozen_string_literal: true

class ReportPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def revenue?
    user.present?
  end

  def outstanding?
    user.present?
  end

  def taxes?
    user.present?
  end
end
