# frozen_string_literal: true

class ReportPolicy < ApplicationPolicy
  def index?
    user.is_a?(User)
  end

  def revenue?
    user.is_a?(User)
  end

  def outstanding?
    user.is_a?(User)
  end

  def taxes?
    user.is_a?(User)
  end
end
