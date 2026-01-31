# frozen_string_literal: true

require "rails_helper"
require "pundit/rspec"

RSpec.describe PropertyPolicy, type: :policy do
  subject { described_class }

  let(:user) { create(:user) }
  let(:property) { create(:property) }

  context "when user is an admin" do
    let(:user) { create(:user, :admin) }

    permissions :index?, :show?, :create?, :new?, :update?, :edit?, :destroy? do
      it "grants access" do
        is_expected.to permit(user, property)
      end
    end
  end

  context "when user is associated with the property's owner" do
    before do
      create(:user_association, user: user, associable: property.owner)
    end

    permissions :index?, :show?, :create?, :new?, :update?, :edit?, :destroy? do
      it "grants access" do
        is_expected.to permit(user, property)
      end
    end
  end

  context "when user is a tenant with a lease on the property" do
    let(:tenant) { create(:tenant) }

    before do
      create(:lease, tenant: tenant, property: property)
      create(:user_association, user: user, associable: tenant)
    end

    permissions :index?, :show? do
      it "grants access" do
        is_expected.to permit(user, property)
      end
    end

    permissions :create?, :new?, :update?, :edit?, :destroy? do
      it "denies access" do
        is_expected.not_to permit(user, property)
      end
    end
  end

  context "when user is a tenant with a lease on another property" do
    let(:tenant) { create(:tenant) }
    let(:other_property) { create(:property) }

    before do
      create(:lease, tenant: tenant, property: other_property)
      create(:user_association, user: user, associable: tenant)
    end

    permissions :show?, :create?, :new?, :update?, :edit?, :destroy? do
      it "denies access" do
        is_expected.not_to permit(user, property)
      end
    end
  end

  context "when user is unrelated" do
    permissions :show?, :create?, :new?, :update?, :edit?, :destroy? do
      it "denies access" do
        is_expected.not_to permit(user, property)
      end
    end
  end

  describe "Scope" do
    let(:user) { create(:user) }

    def resolve_scope
      described_class::Scope.new(user, Property).resolve
    end

    context "when user is admin" do
      let(:user) { create(:user, :admin) }

      it "includes all properties" do
        properties = create_list(:property, 3)
        expect(resolve_scope).to include(*properties)
      end
    end

    context "when user is associated with property owner" do
      let!(:owned) { create(:property) }
      let!(:unrelated) { create(:property) }

      before { create(:user_association, user: user, associable: owned.owner) }

      it "includes owned property" do
        expect(resolve_scope).to include(owned)
      end

      it "excludes unrelated properties" do
        expect(resolve_scope).not_to include(unrelated)
      end
    end

    context "when user is tenant with lease on property" do
      let!(:leased) { create(:property) }
      let!(:unrelated) { create(:property) }

      before do
        tenant = create(:tenant)
        create(:user_association, user: user, associable: tenant)
        create(:lease, tenant: tenant, property: leased)
      end

      it "includes leased property" do
        expect(resolve_scope).to include(leased)
      end

      it "excludes unrelated properties" do
        expect(resolve_scope).not_to include(unrelated)
      end
    end
  end
end
