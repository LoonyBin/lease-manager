# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserPolicy do
  subject { described_class.new(user, record) }

  let(:user) { create(:user) }
  let(:record) { create(:user) }

  context "when user is an admin" do
    let(:user) { create(:user, :admin) }

    it { is_expected.to permit_actions(%i[index show create new update edit destroy]) }
  end

  context "when user views their own profile" do
    let(:record) { user }

    it { is_expected.to permit_action(:show) }
    it { is_expected.to forbid_actions(%i[index create new update edit destroy]) }
  end

  context "when user views another user" do
    it { is_expected.to forbid_actions(%i[index show create new update edit destroy]) }
  end
end
