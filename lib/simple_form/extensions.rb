# frozen_string_literal: true

# Custom helpers for SimpleForm::FormBuilder
module SimpleForm
  module Extensions
    def grid_inputs(columns: 4, gap: 6, &)
      grid_classes = "form-inputs grid grid-cols-1 md:grid-cols-#{columns} gap-#{gap} [&>*]:min-w-0"
      template.content_tag(:div, class: grid_classes, &)
    end

    def form_actions(justify: "end", gap: 4, &)
      actions_classes = "form-actions mt-8 flex justify-#{justify} gap-#{gap}"

      content = if block_given?
                  template.capture(&)
                else
                  template.link_to("Back", :back, class: "btn btn-ghost") +
                    button(:submit, class: "btn btn-primary")
                end

      template.content_tag(:div, content, class: actions_classes)
    end
  end
end
