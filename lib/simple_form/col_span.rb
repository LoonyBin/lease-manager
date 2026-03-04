# frozen_string_literal: true

# Prepend col: option support so super resolves through the module chain
module SimpleForm
  module ColSpan
    def input(attribute_name, options = {}, &)
      col = options.delete(:col) || 2
      options[:wrapper_html] ||= {}
      existing = options[:wrapper_html][:class]
      options[:wrapper_html][:class] = ["md:col-span-#{col}", existing].compact.join(" ")
      super
    end
  end
end
