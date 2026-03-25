# frozen_string_literal: true

# Adds a `presettable` option to `f.association` that renders a readonly
# display field + hidden ID field when the foreign key is already set, and
# falls back to the normal select dropdown otherwise.
#
# Usage:
#   = f.association :property, presettable: true, collection: ...
#
# When property_id is present this renders the equivalent of:
#   = f.input :property, as: :string, readonly: true, input_html: { value: record.name }
#   = f.input :property_id, as: :hidden
#
module SimpleForm
  module PresettableAssociation
    LABEL_METHODS = %i[to_label name title to_s].freeze

    def association(association_name, options = {}, &)
      presettable = options.delete(:presettable)
      fk = :"#{association_name}_id"

      if presettable && object.respond_to?(:"#{fk}?") && object.public_send(:"#{fk}?")
        build_locked_association(association_name, fk, options)
      else
        super
      end
    end

    private

    def build_locked_association(association_name, foreign_key, options)
      record = object.public_send(association_name)
      display = resolve_display_value(record)

      readonly_opts = { as: :string, readonly: true, input_html: { value: display } }
      readonly_opts[:col] = options[:col] if options[:col]
      input(association_name, readonly_opts) + input(foreign_key, as: :hidden)
    end

    def resolve_display_value(record)
      LABEL_METHODS.each do |method|
        return record.public_send(method) if record.respond_to?(method)
      end
    end
  end
end
