# frozen_string_literal: true

require "rails_helper"

RSpec.describe LeaseHelper do
  describe "#billable_months" do
    let(:lease) { build(:lease, start_date: Date.new(2023, 1, 15), duration_months: 3) }

    let(:expected_months) do
      [
        Date.new(2023, 1, 1),
        Date.new(2023, 2, 1),
        Date.new(2023, 3, 1)
      ]
    end

    it "returns an array of months covering the lease duration" do
      expect(helper.billable_months(lease)).to eq(expected_months)
    end

    it "handles nil start_date gracefully" do
      lease.start_date = nil
      expect(helper.billable_months(lease)).to eq([])
    end
  end
end
