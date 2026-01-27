# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentAllocation do
  it { is_expected.to belong_to(:payment) }
  it { is_expected.to belong_to(:invoice) }

  it { is_expected.to validate_presence_of(:amount) }
  it { is_expected.to validate_numericality_of(:amount).is_greater_than(0) }
end
