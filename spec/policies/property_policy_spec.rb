# frozen_string_literal: true

require "rails_helper"

RSpec.describe PropertyPolicy do
  subject { described_class.new(user, property) }

  let(:user) { create(:user) }
  let(:property) { create(:property) }

  context "when user is an admin" do
    let(:user) { create(:user, :admin) }

    it { is_expected.to permit_actions(%i[index show create new update edit destroy]) }
  end

  context "when user is associated with the property's owner" do
    before do
      create(:user_association, user: user, associable: property.owner)
    end

    it { is_expected.to permit_actions(%i[index show create new update edit destroy]) }
  end

  context "when user is a tenant with a lease on the property" do
    let(:tenant) { create(:tenant) }

    before do
      create(:lease, tenant: tenant, property: property)
      create(:user_association, user: user, associable: tenant)
    end

    it { is_expected.to permit_actions(%i[index show]) }
    it { is_expected.to forbid_actions(%i[create new update edit destroy]) }
  end

  context "when user is a tenant with a lease on another property" do
    let(:tenant) { create(:tenant) }
    let(:other_property) { create(:property) }

    before do
      create(:lease, tenant: tenant, property: other_property)
      create(:user_association, user: user, associable: tenant)
    end

    it { is_expected.to forbid_actions(%i[show create new update edit destroy]) }
  end

  context "when user is unrelated" do
    it { is_expected.to forbid_actions(%i[show create new update edit destroy]) }
  end

  describe "Scope" do
    subject(:scope) { described_class::Scope.new(user, Property).resolve }

    let(:user) { create(:user) }

    context "when user is admin" do
      let(:user) { create(:user, :admin) }

      it "includes all properties" do
        properties = create_list(:property, 3)
        expect(scope).to include(*properties)
      end
    end

    context "when user is associated with property owner" do
      let!(:owned) { create(:property) }
      let!(:unrelated) { create(:property) }

      before { create(:user_association, user: user, associable: owned.owner) }

      it "includes owned property" do
        expect(scope).to include(owned)
      end

      it "excludes unrelated properties" do
        expect(scope).not_to include(unrelated)
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
        expect(scope).to include(leased)
      end

      it "excludes unrelated properties" do
        expect(scope).not_to include(unrelated)
      end
    end
  end
end
