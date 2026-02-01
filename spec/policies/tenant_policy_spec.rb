# frozen_string_literal: true

require "rails_helper"

RSpec.describe TenantPolicy do
  subject { described_class.new(user, tenant) }

  let(:user) { create(:user) }
  let(:tenant) { create(:tenant) }

  context "when user is an admin" do
    let(:user) { create(:user, :admin) }

    it { is_expected.to permit_actions(%i[index show create new update edit destroy]) }
  end

  context "when user is associated with the tenant" do
    before do
      create(:user_association, user: user, associable: tenant)
    end

    it { is_expected.to permit_actions(%i[show update edit]) }
    it { is_expected.to forbid_actions(%i[create new destroy]) }
  end

  context "when user is an owner of the tenant" do
    let(:owner) { create(:owner) }

    before do
      property = create(:property, owner: owner)
      create(:lease, tenant: tenant, property: property)
      create(:user_association, user: user, associable: owner)
    end

    it { is_expected.to permit_action(:show) }
    it { is_expected.to forbid_actions(%i[create new update edit destroy]) }
  end

  context "when user is unrelated" do
    it { is_expected.to forbid_actions(%i[show create new update edit destroy]) }
  end

  describe "Scope" do
    subject(:scope) { described_class::Scope.new(user, Tenant).resolve }

    let!(:managed_tenant) { create(:tenant, name: "Managed Tenant") }
    let!(:leased_tenant) { create(:tenant, name: "Leased Tenant") }
    let!(:unrelated_tenant) { create(:tenant, name: "Unrelated Tenant") }
    let(:user) { create(:user) }

    context "when user is admin" do
      let(:user) { create(:user, :admin) }

      it "includes all tenants" do
        expect(scope).to include(managed_tenant, leased_tenant, unrelated_tenant)
      end
    end

    context "when user manages tenant" do
      before { create(:user_association, user: user, associable: managed_tenant) }

      it "includes managed tenant" do
        expect(scope).to include(managed_tenant)
      end

      it "excludes others" do
        expect(scope).not_to include(leased_tenant, unrelated_tenant)
      end
    end

    context "when user is owner of leased tenant" do
      before do
        owner = create(:owner)
        property = create(:property, owner: owner)
        create(:user_association, user: user, associable: owner)
        create(:lease, tenant: leased_tenant, property: property)
      end

      it "includes leased tenant" do
        expect(scope).to include(leased_tenant)
      end

      it "excludes others" do
        expect(scope).not_to include(managed_tenant, unrelated_tenant)
      end
    end
  end
end
