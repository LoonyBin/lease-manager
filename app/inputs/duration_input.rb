# frozen_string_literal: true

class DurationInput < SimpleForm::Inputs::Base
  def input(_wrapper_options)
    template.content_tag(:div, class: "join w-full flex", data: { controller: "duration-input" }) do
      duration_hidden_field + template.safe_join(unit_inputs)
    end
  end

  private

  def duration_hidden_field
    @builder.hidden_field(attribute_name, data: { duration_input_target: "hidden" })
  end

  def requested_units
    options[:units] || %i[years months days hours minutes seconds]
  end

  def parsed_duration_parts
    current_value = @builder.object.send(attribute_name)

    if current_value.is_a?(String)
      current_value = begin
        ActiveSupport::Duration.parse(current_value)
      rescue StandardError
        nil
      end
    end

    current_value.is_a?(ActiveSupport::Duration) ? current_value.parts : {}
  end

  def unit_inputs
    parts = parsed_duration_parts
    requested_units.map { |unit| build_unit_input(unit, parts.fetch(unit, 0)) }
  end

  def build_unit_input(unit, value)
    template.content_tag(:div, class: "relative join-item flex-1") do
      number_input(unit, value) + unit_label(unit)
    end
  end

  def number_input(unit, value)
    template.number_field_tag(
      nil, # No name so it doesn't get submitted directly
      value,
      class: "input input-bordered join-item w-full min-w-0 pr-8",
      min: 0,
      data: { duration_input_target: "unit", unit: unit, action: "input->duration-input#update" }
    )
  end

  def unit_label(unit)
    css_class = "absolute right-3 top-0 h-full flex items-center " \
                "text-base-content/50 pointer-events-none text-xs font-bold"

    template.content_tag(
      :div,
      unit.to_s.first.upcase,
      class: css_class,
      title: unit.to_s.humanize
    )
  end
end
