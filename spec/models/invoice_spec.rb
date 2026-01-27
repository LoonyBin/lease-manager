# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoice do
  describe "associations" do
    it { is_expected.to belong_to(:lease) }
    it { is_expected.to have_many(:line_items).dependent(:destroy) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:date) }
    it { is_expected.to validate_presence_of(:status) }

    it {
      is_expected.to define_enum_for(:status).with_values(draft: 0, finalized: 1, sent: 2, paid: 3, cancelled: 4,
                                                          partially_paid: 5)
    }
  end
end
