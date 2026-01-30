# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationPolicy do
  subject { described_class.new(user, record) }

  let(:record) { build(:tenant) }

  context "when user is admin" do
    let(:user) { build(:user, role: :admin) }

    it { is_expected.to be_index }
    it { is_expected.to be_show }
    it { is_expected.to be_create }
    it { is_expected.to be_new }
    it { is_expected.to be_update }
    it { is_expected.to be_edit }
    it { is_expected.to be_destroy }
  end

  context "when user is normal" do
    let(:user) { build(:user, role: :normal) }

    it { is_expected.not_to be_index }
    it { is_expected.not_to be_show }
    it { is_expected.not_to be_create }
    it { is_expected.not_to be_new }
    it { is_expected.not_to be_update }
    it { is_expected.not_to be_edit }
    it { is_expected.not_to be_destroy }
  end

  context "when user is nil" do
    let(:user) { nil }

    it { is_expected.not_to be_index }
    it { is_expected.not_to be_show }
    it { is_expected.not_to be_create }
    it { is_expected.not_to be_new }
    it { is_expected.not_to be_update }
    it { is_expected.not_to be_edit }
    it { is_expected.not_to be_destroy }
  end
end
