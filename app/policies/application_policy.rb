# frozen_string_literal: true

class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user || User::Anonymous.new
    @record = record
  end

  def index?
    admin?
  end

  def show?
    admin?
  end

  def create?
    admin?
  end

  def new?
    create?
  end

  def update?
    admin?
  end

  def edit?
    update?
  end

  def destroy?
    admin?
  end

  private

  def admin?
    user.admin?
  end

  class Scope
    def initialize(user, scope)
      @user = user || User::Anonymous.new
      @scope = scope
    end

    def resolve
      return scope.none unless user.admin?

      scope.all
    end

    private

    attr_reader :user, :scope
  end
end
