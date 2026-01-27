# frozen_string_literal: true

require "rails_helper"

RSpec.describe Owner do
  describe "associations" do
    it { is_expected.to have_many(:properties) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:address) }
    it { is_expected.to validate_numericality_of(:invoice_sequence).only_integer.is_greater_than_or_equal_to(0) }
  end

  describe "defaults" do
    it "sets default invoice_sequence to 0" do
      owner = described_class.new
      expect(owner.invoice_sequence).to eq(0)
    end
  end
end
