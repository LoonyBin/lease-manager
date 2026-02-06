# frozen_string_literal: true

require "rails_helper"

RSpec.describe User do
  subject { build(:user) }

  describe "associations" do
    it { is_expected.to have_many(:user_associations).dependent(:destroy) }
    it { is_expected.to have_many(:owners).through(:user_associations) }
    it { is_expected.to have_many(:tenants).through(:user_associations) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:uid) }
    it { is_expected.to validate_presence_of(:provider) }
    it { is_expected.to validate_uniqueness_of(:uid).scoped_to(:provider) }
  end

  describe ".from_omniauth" do
    let(:auth) do
      OmniAuth::AuthHash.new(
        provider: "developer",
        uid: "test-uid",
        info: {
          email: "test@example.com",
          name: "Test User"
        }
      )
    end

    context "when user does not exist" do
      it "creates a new user" do
        expect { described_class.from_omniauth(auth) }.to change(described_class, :count).by(1)
      end

      it "sets the user attributes from auth hash" do
        user = described_class.from_omniauth(auth)
        expect(user).to have_attributes(provider: "developer", uid: "test-uid", email: "test@example.com",
                                        name: "Test User")
      end
    end

    context "when user already exists" do
      before { create(:user, provider: "developer", uid: "test-uid") }

      it "does not create a new user" do
        expect { described_class.from_omniauth(auth) }.not_to change(described_class, :count)
      end

      it "updates the user attributes" do
        auth.info.name = "New Name"

        user = described_class.from_omniauth(auth)
        expect(user.reload).to have_attributes(name: "New Name")
      end
    end
  end
end
