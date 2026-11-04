# frozen_string_literal: true

require "rails_helper"

RSpec.describe BankStatementPolicy do
  subject { described_class.new(user, BankStatement.new) }

  context "when the user is an admin" do
    let(:user) { create(:user, :admin) }

    it { is_expected.to permit_actions(%i[index show new create]) }
  end

  context "when the user is not an admin" do
    let(:user) { create(:user) }

    it { is_expected.to forbid_actions(%i[index show new create]) }
  end
end
