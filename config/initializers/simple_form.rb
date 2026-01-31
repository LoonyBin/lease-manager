# frozen_string_literal: true

# Use this setup block to configure all options available in SimpleForm.
SimpleForm.setup do |config| # rubocop:disable Metrics/BlockLength
  config.wrappers :default, class: "form-control w-full mb-2" do |b|
    b.use :html5
    b.use :placeholder
    b.optional :maxlength
    b.optional :minlength
    b.optional :pattern
    b.optional :min_max
    b.optional :readonly
    b.use :label, class: "label" do |ba|
      ba.use :label_text, class: "label-text font-bold"
    end
    b.use :input, class: "input input-bordered w-full"

    b.use :hint,  wrap_with: { tag: :div, class: "label-text-alt mt-1 text-gray-500" }
    b.use :error, wrap_with: { tag: :div, class: "label-text-alt mt-1 text-error font-bold" }
  end

  config.default_wrapper = :default

  config.boolean_style = :inline

  config.button_class = "btn btn-primary"

  config.error_method = :to_sentence

  config.error_notification_tag = :div

  config.error_notification_class = "alert alert-error mb-4"

  config.label_class = "label"

  # Container around the form itself
  config.default_form_class = "card-body"

  config.browser_validations = false

  config.boolean_label_class = "checkbox"
  config.input_class = "input input-bordered w-full"
end
