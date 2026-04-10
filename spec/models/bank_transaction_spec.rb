# frozen_string_literal: true

require "rails_helper"

RSpec.describe BankTransaction do
  subject(:bank_transaction) { build(:bank_transaction) }

  describe "validations" do
    it { is_expected.to validate_presence_of(:date) }
    it { is_expected.to validate_presence_of(:amount) }
    it { is_expected.to validate_numericality_of(:amount) }

    it {
      expect(bank_transaction).to define_enum_for(:status).with_values(unmatched: 0, matched: 1, confirmed: 2,
                                                                       rejected: 3)
    }
  end

  describe "associations" do
    it { is_expected.to belong_to(:bank_statement) }
    it { is_expected.to belong_to(:matched_payment).optional }
  end
end
