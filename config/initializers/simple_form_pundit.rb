# frozen_string_literal: true

# Automatically apply policy_scope to simple_form associations
# when no explicit collection is provided.
#
# This ensures that dropdowns only show records the current user
# is authorized to access.
#
# Usage:
#   = f.association :owner                        # Uses policy_scope(Owner)
#   = f.association :owner, collection: Owner.all # Explicit collection, no scoping
#
module SimpleFormPundit
  def association(association, options = {}, &)
    unless options.key?(:collection)
      reflection = object.class.reflect_on_association(association)
      if reflection
        klass = reflection.klass
        options = options.merge(collection: @template.policy_scope(klass))
      end
    end
    super
  end
end

SimpleForm::FormBuilder.prepend(SimpleFormPundit)
