# frozen_string_literal: true

require "rails_helper"

RSpec.describe BankTransactionPolicy do
  subject { described_class.new(user, build(:bank_transaction)) }

  let(:actions) { %i[confirm reject rematch choose] }

  context "when the user is an admin" do
    let(:user) { create(:user, :admin) }

    it { is_expected.to permit_actions(actions) }
  end

  context "when the user is not an admin" do
    let(:user) { create(:user) }

    it { is_expected.to forbid_actions(actions) }
  end

  context "when nobody is signed in" do
    let(:user) { nil }

    it { is_expected.to forbid_actions(actions) }
  end
end
