# frozen_string_literal: true

require "rails_helper"

RSpec.describe BankStatement do
  subject(:bank_statement) { build(:bank_statement) }

  describe "validations" do
    it { is_expected.to validate_presence_of(:filename) }
    it { is_expected.to define_enum_for(:status).with_values(pending: 0, processed: 1) }
  end

  describe "associations" do
    it { is_expected.to have_many(:bank_transactions).dependent(:destroy) }
    it { is_expected.to have_one_attached(:file) }
  end
end
