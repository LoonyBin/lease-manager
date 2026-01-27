# frozen_string_literal: true

require "rails_helper"

RSpec.describe Owner do
  describe "associations" do
    it { is_expected.to have_many(:properties) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:address) }
  end
end
