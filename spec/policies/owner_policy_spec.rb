# frozen_string_literal: true

require "rails_helper"
require "pundit/rspec"

RSpec.describe OwnerPolicy, type: :policy do
  subject { described_class }

  let(:user) { create(:user) }
  let(:owner) { create(:owner) }

  context "when user is an admin" do
    let(:user) { create(:user, :admin) }

    permissions :index?, :show?, :create?, :new?, :update?, :edit?, :destroy? do
      it "grants access" do
        is_expected.to permit(user, owner)
      end
    end
  end

  context "when user is associated with the owner" do
    before do
      create(:user_association, user: user, associable: owner)
    end

    permissions :show?, :update?, :edit?, :destroy? do
      it "grants access" do
        is_expected.to permit(user, owner)
      end
    end

    permissions :create?, :new? do
      it "denies access" do
        is_expected.not_to permit(user, owner)
      end
    end
  end

  context "when user is a tenant of the owner" do
    let(:tenant) { create(:tenant) }

    before do
      property = create(:property, owner: owner)
      create(:lease, tenant: tenant, property: property)
      create(:user_association, user: user, associable: tenant)
    end

    permissions :show? do
      it "grants access" do
        is_expected.to permit(user, owner)
      end
    end

    permissions :create?, :new?, :update?, :edit?, :destroy? do
      it "denies access" do
        is_expected.not_to permit(user, owner)
      end
    end
  end

  context "when user is a tenant of another owner" do
    let(:tenant) { create(:tenant) }
    let(:other_owner) { create(:owner) }

    before do
      property = create(:property, owner: other_owner)
      create(:lease, tenant: tenant, property: property)
      create(:user_association, user: user, associable: tenant)
    end

    permissions :show? do
      it "denies access" do
        is_expected.not_to permit(user, owner)
      end
    end
  end

  context "when user is unrelated" do
    permissions :show?, :create?, :new?, :update?, :edit?, :destroy? do
      it "denies access" do
        is_expected.not_to permit(user, owner)
      end
    end
  end

  describe "Scope" do
    subject(:scope) { described_class::Scope.new(user, Owner).resolve }

    let!(:managed_owner) { create(:owner, name: "Managed Owner") }
    let!(:leased_owner) { create(:owner, name: "Leased Owner") }
    let!(:unrelated_owner) { create(:owner, name: "Unrelated Owner") }
    let(:user) { create(:user) }

    context "when user is admin" do
      let(:user) { create(:user, :admin) }

      it "includes all owners" do
        expect(scope).to include(managed_owner, leased_owner, unrelated_owner)
      end
    end

    context "when user manages owner" do
      before { create(:user_association, user: user, associable: managed_owner) }

      it "includes managed owner" do
        expect(scope).to include(managed_owner)
      end

      it "excludes others" do
        expect(scope).not_to include(leased_owner, unrelated_owner)
      end
    end

    context "when user is tenant of owner" do
      before do
        tenant = create(:tenant)
        property = create(:property, owner: leased_owner)
        create(:user_association, user: user, associable: tenant)
        create(:lease, tenant: tenant, property: property)
      end

      it "includes leased owner" do
        expect(scope).to include(leased_owner)
      end

      it "excludes others" do
        expect(scope).not_to include(managed_owner, unrelated_owner)
      end
    end
  end
end
