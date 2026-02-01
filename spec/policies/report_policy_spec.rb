# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReportPolicy do
  subject { described_class.new(user, :report) }

  context "when user is an admin" do
    let(:user) { build_stubbed(:user, :admin) }

    it { is_expected.to permit_actions(%i[index revenue outstanding taxes]) }
  end

  context "when user is a normal user" do
    let(:user) { build_stubbed(:user) }

    it { is_expected.to permit_actions(%i[index revenue outstanding taxes]) }
  end

  context "when user is nil" do
    let(:user) { nil }

    it { is_expected.to forbid_actions(%i[index revenue outstanding taxes]) }
  end
end
