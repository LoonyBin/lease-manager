# frozen_string_literal: true

require "rails_helper"

RSpec.describe Property do
  subject { build(:property) }

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:address) }
  end
end
