# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReportPolicy do
  subject { described_class.new(user, :report) }

  context "when user is admin" do
    let(:user) { build(:user, role: :admin) }

    it { is_expected.to be_index }
    it { is_expected.to be_revenue }
    it { is_expected.to be_outstanding }
    it { is_expected.to be_taxes }
  end

  context "when user is normal" do
    let(:user) { build(:user, role: :normal) }

    it { is_expected.to be_index }
    it { is_expected.to be_revenue }
    it { is_expected.to be_outstanding }
    it { is_expected.to be_taxes }
  end

  context "when user is nil" do
    let(:user) { nil }

    it { is_expected.not_to be_index }
    it { is_expected.not_to be_revenue }
    it { is_expected.not_to be_outstanding }
    it { is_expected.not_to be_taxes }
  end
end
