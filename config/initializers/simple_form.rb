# frozen_string_literal: true

#
# Uncomment this and change the path if necessary to include your own
# components.
# See https://github.com/heartcombo/simple_form#custom-components to know
# more about custom components.
# Dir[Rails.root.join('lib/components/**/*.rb')].each { |f| require f }
#
# Use this setup block to configure all options available in SimpleForm.
SimpleForm.setup do |config|
  # Wrappers are used by the form builder to generate a
  # complete input. You can remove any component from the
  # wrapper, change the order or even add your own to the
  # stack. The options given below are used to wrap the
  # whole input.

  config.wrappers :default, tag: "div", class: "form-control w-full", error_class: "", valid_class: "" do |b|
    b.use :html5
    b.use :placeholder
    b.optional :maxlength
    b.optional :minlength
    b.optional :pattern
    b.optional :min_max
    b.optional :readonly

    b.use :label, class: "label-text block font-medium mb-2"
    b.use :input,
          class: "input input-bordered w-full"
    b.use :full_error, wrap_with: { tag: "p", class: "mt-2 text-sm text-red-600" }
    b.use :hint, wrap_with: { tag: :label, class: "label label-text-alt" }
  end

  config.wrappers :textarea, tag: "div", class: "form-control w-full", error_class: "", valid_class: "" do |b|
    b.use :html5
    b.use :placeholder
    b.optional :maxlength
    b.optional :minlength
    b.optional :pattern
    b.optional :min_max
    b.optional :readonly

    b.use :label, class: "label-text block font-medium mb-2"
    b.use :input,
          class: "textarea textarea-bordered w-full"
    b.use :full_error, wrap_with: { tag: "p", class: "mt-2 text-sm text-red-600" }
    b.use :hint, wrap_with: { tag: :label, class: "label label-text-alt" }
  end

  config.wrappers :select, tag: "div", class: "form-control w-full", error_class: "", valid_class: "" do |b|
    b.use :html5
    b.optional :readonly
    b.use :label, class: "label-text block font-medium mb-2"
    b.use :input, class: "select select-bordered w-full"
    b.use :full_error, wrap_with: { tag: "p", class: "mt-2 text-sm text-red-600" }
    b.use :hint, wrap_with: { tag: :label, class: "label label-text-alt" }
  end

  config.wrappers :file, tag: "div", class: "form-control w-full", error_class: "", valid_class: "" do |b|
    b.use :html5
    b.optional :readonly
    b.use :label, class: "label-text block font-medium mb-2"
    b.use :input, class: "file-input file-input-bordered w-full"
    b.use :full_error, wrap_with: { tag: "p", class: "mt-2 text-sm text-red-600" }
    b.use :hint, wrap_with: { tag: :label, class: "label label-text-alt" }
  end

  config.boolean_style = :inline
  config.include_default_input_wrapper_class = false
  config.item_wrapper_tag = :div
  config.wrappers :vertical_radio, tag: "div", class: "form-control w-fit", error_class: "",
                                   item_wrapper_class: "form-check",
                                   item_label_class: "label gap-2 items-center justify-start" do |b|
    b.use :html5
    b.optional :readonly
    b.use :label, class: "label-text"
    b.use :input, class: "radio"
    b.use :full_error, wrap_with: { tag: "p", class: "mt-2 text-sm text-red-600" }
    b.use :hint, wrap_with: { tag: :label, class: "label label-text-alt" }
  end
  config.default_wrapper = :default

  # Define the way to render check boxes / radio buttons with labels.
  # Defaults to :nested for bootstrap config.
  #   inline: input + label
  #   nested: label > input
  config.boolean_style = :nested

  # Default class for buttons
  config.button_class = nil

  # Method used to tidy up errors. Specify any Rails Array method.
  # :first lists the first message for each field.
  # Use :to_sentence to list all errors for each field.
  # config.error_method = :first

  # Default tag used for error notification helper.
  config.error_notification_tag = :div
  # CSS class to add for error notification helper.
  config.error_notification_class = ""
  config.label_text = ->(label, _required, _explicit_label) { label.to_s }

  config.default_form_class = nil

  # You can define which elements should obtain additional classes
  config.generate_additional_classes_for = []

  config.browser_validations = false

  config.wrapper_mappings = {
    string: :default,
    text: :textarea,
    select: :select,
    file: :file,
    # check_boxes: :vertical_radio_and_checkboxes,
    radio_buttons: :vertical_radio
    # prepend_string: :prepend_string,
    # append_string: :append_string,
  }
  config.boolean_label_class = "checkbox"
end

# Include custom helpers and prepend col-span support from lib/
Rails.application.config.after_initialize do
  SimpleForm::FormBuilder.include(SimpleForm::Extensions)
  SimpleForm::FormBuilder.prepend(SimpleForm::ColSpan)
  SimpleForm::FormBuilder.prepend(SimpleForm::PresettableAssociation)
end
