# frozen_string_literal: true

class User
  class Anonymous
    def admin?
      false
    end

    def name
      "Guest"
    end

    def email
      ""
    end

    def persisted?
      false
    end

    def id
      nil
    end

    def owners
      Owner.none
    end

    def tenants
      Tenant.none
    end
  end
end
