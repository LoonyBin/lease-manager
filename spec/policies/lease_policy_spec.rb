# frozen_string_literal: true

require "rails_helper"
require "pundit/rspec"

RSpec.describe LeasePolicy, type: :policy do
  subject { described_class }

  let(:user) { create(:user) }
  let(:lease) { create(:lease) }

  context "when user is an admin" do
    let(:user) { create(:user, :admin) }

    permissions :index?, :show?, :create?, :new?, :update?, :edit?, :destroy? do
      it "grants access" do
        is_expected.to permit(user, lease)
      end
    end
  end

  context "when user is associated with the lease's property owner" do
    before do
      create(:user_association, user: user, associable: lease.property.owner)
    end

    permissions :index?, :show?, :create?, :new?, :update?, :edit?, :destroy? do
      it "grants access" do
        is_expected.to permit(user, lease)
      end
    end
  end

  context "when user is associated with the lease's tenant" do
    before do
      create(:user_association, user: user, associable: lease.tenant)
    end

    permissions :index?, :show? do
      it "grants access" do
        is_expected.to permit(user, lease)
      end
    end

    permissions :create?, :new?, :update?, :edit?, :destroy? do
      it "denies access" do
        is_expected.not_to permit(user, lease)
      end
    end
  end

  context "when user is a tenant on a different lease" do
    let(:other_lease) { create(:lease) }

    before do
      create(:user_association, user: user, associable: other_lease.tenant)
    end

    permissions :show?, :create?, :new?, :update?, :edit?, :destroy? do
      it "denies access" do
        is_expected.not_to permit(user, lease)
      end
    end
  end

  context "when user is unrelated" do
    permissions :show?, :create?, :new?, :update?, :edit?, :destroy? do
      it "denies access" do
        is_expected.not_to permit(user, lease)
      end
    end
  end

  describe "Scope" do
    let(:user) { create(:user) }

    def resolve_scope
      described_class::Scope.new(user, Lease).resolve
    end

    context "when user is admin" do
      let(:user) { create(:user, :admin) }

      it "includes all leases" do
        leases = create_list(:lease, 3)
        expect(resolve_scope).to include(*leases)
      end
    end

    context "when user is associated with property owner" do
      let!(:owned_lease) { create(:lease) }
      let!(:unrelated_lease) { create(:lease) }

      before { create(:user_association, user: user, associable: owned_lease.property.owner) }

      it "includes owned lease" do
        expect(resolve_scope).to include(owned_lease)
      end

      it "excludes unrelated leases" do
        expect(resolve_scope).not_to include(unrelated_lease)
      end
    end

    context "when user is associated with tenant" do
      let!(:tenant_lease) { create(:lease) }
      let!(:unrelated_lease) { create(:lease) }

      before { create(:user_association, user: user, associable: tenant_lease.tenant) }

      it "includes tenant lease" do
        expect(resolve_scope).to include(tenant_lease)
      end

      it "excludes unrelated leases" do
        expect(resolve_scope).not_to include(unrelated_lease)
      end
    end
  end
end
