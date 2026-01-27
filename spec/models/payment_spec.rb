# frozen_string_literal: true

require "rails_helper"

RSpec.describe Payment do
  it { is_expected.to belong_to(:lease) }
  it { is_expected.to have_many(:payment_allocations) }
  it { is_expected.to have_many(:invoices).through(:payment_allocations) }

  it { is_expected.to validate_presence_of(:amount) }
  it { is_expected.to validate_numericality_of(:amount).is_greater_than(0) }
  it { is_expected.to validate_presence_of(:date) }
  it { is_expected.to validate_presence_of(:mode) }

  it do
    expected_modes = {
      rtgs: 0, neft: 1, imps: 2, upi: 3, cheque: 4,
      cash: 5, demand_draft: 6, tax_deducted_at_source: 7
    }
    is_expected.to define_enum_for(:mode).with_values(expected_modes)
  end
end
