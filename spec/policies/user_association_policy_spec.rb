# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserAssociationPolicy do
  subject { described_class.new(user, user_association) }

  let(:user_association) { build(:user_association) }

  context "when user is admin" do
    let(:user) { build(:user, role: :admin) }

    it { is_expected.to be_create }
    it { is_expected.to be_destroy }
  end

  context "when user is normal" do
    let(:user) { build(:user, role: :normal) }

    it { is_expected.not_to be_create }
    it { is_expected.not_to be_destroy }
  end

  context "when user is nil" do
    let(:user) { nil }

    it { is_expected.not_to be_create }
    it { is_expected.not_to be_destroy }
  end
end
