# frozen_string_literal: true

require "rails_helper"

RSpec.describe Payment do
  it { is_expected.to belong_to(:lease) }
  it { is_expected.to have_many(:payment_allocations) }
  it { is_expected.to have_many(:invoices).through(:payment_allocations) }

  it { is_expected.to validate_presence_of(:amount) }
  it { is_expected.to validate_numericality_of(:amount).is_greater_than(0) }
  it { is_expected.to validate_presence_of(:date) }
end
