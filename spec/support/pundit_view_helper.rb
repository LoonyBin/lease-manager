# frozen_string_literal: true

# Provides policy helpers for view specs. By default, permits all actions
# (simulating an admin user viewing the page).
module PunditViewHelper
  class PermissivePolicy
    def method_missing(_method, *_args)
      true
    end

    def respond_to_missing?(_method, _include_private = false)
      true
    end
  end
end

RSpec.configure do |config|
  config.before(:each, type: :view) do
    without_partial_double_verification do
      allow(view).to receive(:policy).and_return(PunditViewHelper::PermissivePolicy.new)
      allow(view).to receive(:policy_scope, &:all)
    end
  end
end
