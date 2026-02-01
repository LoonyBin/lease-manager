# frozen_string_literal: true

module IconHelper
  # Drop-in compatible with heroicon gem (https://github.com/bharget/heroicon)
  # Switch to gem by: 1) Add gem "heroicon" to Gemfile, 2) Delete this file
  #
  # Usage:
  #   heroicon "pencil-square"
  #   heroicon "pencil-square", variant: :outline
  #   heroicon "pencil-square", options: { class: "w-4 h-4" }
  #
  DEFAULT_CLASS = { outline: "w-6 h-6", solid: "w-6 h-6", mini: "w-5 h-5" }.freeze

  # Paths from Heroicons v2: https://heroicons.com
  # rubocop:disable Layout/LineLength
  ICONS = {
    outline: {
      "pencil-square" => "M16.862 4.487l1.687-1.688a1.875 1.875 0 112.652 2.652L10.582 16.07a4.5 4.5 0 01-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 011.13-1.897l8.932-8.931zm0 0L19.5 7.125M18 14v4.75A2.25 2.25 0 0115.75 21H5.25A2.25 2.25 0 013 18.75V8.25A2.25 2.25 0 015.25 6H10",
      "trash" => "M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0",
      "x-mark" => "M6 18L18 6M6 6l12 12",
      "plus" => "M12 4.5v15m7.5-7.5h-15",
      "document" => "M7 21h10a2 2 0 002-2V9.414a1 1 0 00-.293-.707l-5.414-5.414A1 1 0 0012.586 3H7a2 2 0 00-2 2v14a2 2 0 002 2z",
      "eye" => "M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178zM15 12a3 3 0 11-6 0 3 3 0 016 0z"
    }.freeze
  }.freeze
  # rubocop:enable Layout/LineLength

  def heroicon(name, variant: :outline, options: {})
    path_data = ICONS.dig(variant, name.to_s)
    raise ArgumentError, "Unknown icon: #{name} (variant: #{variant})" unless path_data

    tag.svg(**svg_attributes(variant, options)) { tag.path(d: path_data, **path_attributes) }
  end

  private

  def svg_attributes(variant, options)
    {
      xmlns: "http://www.w3.org/2000/svg",
      fill: "none",
      viewBox: "0 0 24 24",
      stroke: "currentColor",
      "stroke-width": "2",
      class: options[:class] || DEFAULT_CLASS[variant],
      "aria-hidden": options.fetch(:aria_hidden, true)
    }
  end

  def path_attributes
    { "stroke-linecap": "round", "stroke-linejoin": "round" }
  end
end
