# frozen_string_literal: true

module ActiveFiltersHelper
  SCOPE_LABELS = {
    "by_status" => "Status"
  }.freeze

  def render_active_filters(search)
    return unless params[:q]

    filters = params[:q].to_unsafe_h.each_with_object([]) do |(key, value), result|
      next if value.blank? || key.to_s == "s"

      result << build_filter(search, key, value)
    end

    render partial: "shared/active_filters", locals: { filters: filters } if filters.any?
  end

  private

  def build_filter(search, key, value)
    base_attribute = key.to_s.gsub(/_(eq|cont|gteq|lteq|matches|start|end)\z/, "")
    display_value = format_filter_value(search.context.klass, base_attribute, value)
    label = filter_label(key, base_attribute)

    {
      label: "#{label} #{display_value}",
      url: filter_removal_url(key)
    }
  end

  def format_filter_value(klass, attribute, value)
    return format_enum_value(klass, attribute, value) if klass.defined_enums.key?(attribute)

    column = klass.columns_hash[attribute.to_s]
    return format_date_value(value) if column && %i[date datetime].include?(column.type)

    value.to_s.humanize
  end

  def format_enum_value(klass, attribute, value)
    enum_map = klass.defined_enums[attribute].invert
    mapped = enum_map[value.to_i] || enum_map[value]
    mapped&.humanize || value
  end

  def format_date_value(value)
    Date.parse(value).strftime("%b %d, %Y")
  rescue StandardError
    value
  end

  def filter_label(key, base_attribute)
    return SCOPE_LABELS[key.to_s] if SCOPE_LABELS.key?(key.to_s)

    label = base_attribute.humanize
    predicate = key.to_s.split("_").last

    case predicate
    when "gteq" then "#{label} >="
    when "lteq" then "#{label} <="
    when "cont" then "#{label} contains"
    else label
    end
  end

  def filter_removal_url(key)
    url_for(request.params.merge(q: params[:q].to_unsafe_h.merge(key => nil)))
  end
end
