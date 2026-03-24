# frozen_string_literal: true

require "rails_helper"

RSpec.describe LeasePolicy do
  subject { described_class.new(user, lease) }

  let(:user) { create(:user) }
  let(:lease) { create(:lease) }

  context "when user is an admin" do
    let(:user) { create(:user, :admin) }

    it { is_expected.to permit_actions(%i[index show create new update edit destroy]) }
  end

  context "when user is associated with the lease's property owner" do
    before do
      create(:user_association, user: user, associable: lease.property.owner)
    end

    it { is_expected.to permit_actions(%i[index show create new update edit destroy]) }
  end

  context "when user is an owner but the lease is new (unpersisted)" do
    subject { described_class.new(user, Lease.new) }

    let(:owner) { create(:owner) }

    before { create(:user_association, user: user, associable: owner) }

    it { is_expected.to permit_actions(%i[new create]) }
  end

  context "when user is an owner but the property_id belongs to another owner" do
    let(:other_property) { create(:property) }

    subject { described_class.new(user, Lease.new(property_id: other_property.id)) }

    let(:owner) { create(:owner) }

    before { create(:user_association, user: user, associable: owner) }

    it { is_expected.to forbid_actions(%i[create new]) }
  end

  context "when user is associated with the lease's tenant" do
    before do
      create(:user_association, user: user, associable: lease.tenant)
    end

    it { is_expected.to permit_actions(%i[index show]) }
    it { is_expected.to forbid_actions(%i[create new update edit destroy]) }
  end

  context "when user is a tenant on a different lease" do
    let(:other_lease) { create(:lease) }

    before do
      create(:user_association, user: user, associable: other_lease.tenant)
    end

    it { is_expected.to forbid_actions(%i[show create new update edit destroy]) }
  end

  context "when user is unrelated" do
    it { is_expected.to forbid_actions(%i[show create new update edit destroy]) }
  end

  describe "Scope" do
    subject(:scope) { described_class::Scope.new(user, Lease).resolve }

    let(:user) { create(:user) }

    context "when user is admin" do
      let(:user) { create(:user, :admin) }

      it "includes all leases" do
        leases = create_list(:lease, 3)
        expect(scope).to include(*leases)
      end
    end

    context "when user is associated with property owner" do
      let!(:owned_lease) { create(:lease) }
      let!(:unrelated_lease) { create(:lease) }

      before { create(:user_association, user: user, associable: owned_lease.property.owner) }

      it "includes owned lease" do
        expect(scope).to include(owned_lease)
      end

      it "excludes unrelated leases" do
        expect(scope).not_to include(unrelated_lease)
      end
    end

    context "when user is associated with tenant" do
      let!(:tenant_lease) { create(:lease) }
      let!(:unrelated_lease) { create(:lease) }

      before { create(:user_association, user: user, associable: tenant_lease.tenant) }

      it "includes tenant lease" do
        expect(scope).to include(tenant_lease)
      end

      it "excludes unrelated leases" do
        expect(scope).not_to include(unrelated_lease)
      end
    end
  end
end
