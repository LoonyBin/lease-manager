# frozen_string_literal: true

require "rails_helper"

RSpec.describe LineItem do
  describe "associations" do
    it { is_expected.to belong_to(:invoice) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:category) }
    it { is_expected.to validate_presence_of(:amount) }
    it { is_expected.to validate_numericality_of(:amount) }
  end
end
