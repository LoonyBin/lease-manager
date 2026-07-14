# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApiTokenPolicy do
  subject { described_class.new(user, api_token) }

  let(:user) { create(:user) }

  context "when the token belongs to the user" do
    let(:api_token) { create(:api_token, user: user) }

    it { is_expected.to permit_actions(%i[create destroy]) }
  end

  context "when the token belongs to another user" do
    let(:api_token) { create(:api_token) }

    it { is_expected.to forbid_actions(%i[create destroy]) }
  end

  context "when an admin looks at another user's token" do
    let(:user) { create(:user, :admin) }
    let(:api_token) { create(:api_token) }

    it { is_expected.to forbid_actions(%i[create destroy]) }
  end

  describe "Scope" do
    subject(:scope) { described_class::Scope.new(user, ApiToken).resolve }

    it "resolves only to the user's own tokens" do
      own = create(:api_token, user: user)
      create(:api_token)
      expect(scope).to contain_exactly(own)
    end
  end
end
