# frozen_string_literal: true

require "rails_helper"

RSpec.describe IconHelper do
  describe "#heroicon" do
    it "renders an SVG element" do
      result = helper.heroicon("pencil-square")
      expect(result).to have_css("svg")
    end

    it "includes the icon path" do
      result = helper.heroicon("pencil-square")
      expect(result).to have_css("svg path")
    end

    it "applies custom class from options" do
      result = helper.heroicon("pencil-square", options: { class: "w-4 h-4" })
      expect(result).to have_css("svg.w-4.h-4")
    end

    it "sets aria-hidden by default" do
      result = helper.heroicon("pencil-square")
      expect(result).to have_css("svg[aria-hidden='true']")
    end

    it "supports all defined icons" do
      %w[pencil-square trash x-mark plus document].each do |icon_name|
        expect { helper.heroicon(icon_name) }.not_to raise_error
      end
    end

    it "raises ArgumentError for unknown icons" do
      expect { helper.heroicon("unknown-icon") }.to raise_error(ArgumentError, /Unknown icon/)
    end
  end
end
