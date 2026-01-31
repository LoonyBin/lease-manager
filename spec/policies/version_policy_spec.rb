# frozen_string_literal: true

require "rails_helper"
require "pundit/rspec"

RSpec.describe VersionPolicy, type: :policy do
  subject { described_class }

  let(:user) { create(:user) }
  let(:lease) { create(:lease) }
  let(:version) { lease.versions.last }

  before do
    PaperTrail.request.whodunnit = user.id
    lease.update!(rent_amount: lease.rent_amount + 1000)
  end

  describe "permissions" do
    context "when user is an admin" do
      let(:user) { create(:user, :admin) }

      permissions :show?, :destroy? do
        it "grants access to all versions" do
          is_expected.to permit(user, version)
        end
      end
    end

    context "when user can view the versioned resource" do
      before do
        create(:user_association, user: user, associable: lease.property.owner)
      end

      permissions :show? do
        it "grants access to view versions" do
          is_expected.to permit(user, version)
        end
      end

      permissions :destroy? do
        it "denies access to destroy versions" do
          is_expected.not_to permit(user, version)
        end
      end
    end

    context "when user cannot view the versioned resource" do
      permissions :show?, :destroy? do
        it "denies access" do
          is_expected.not_to permit(user, version)
        end
      end
    end
  end

  describe "permissions for destroyed records" do
    before do
      PaperTrail.request.whodunnit = user.id
      lease.destroy
    end

    let(:version) { PaperTrail::Version.where(item_type: "Lease", event: "destroy").last }

    context "when admin views a destroyed record version" do
      let(:user) { create(:user, :admin) }

      permissions :show?, :destroy? do
        it "grants access" do
          is_expected.to permit(user, version)
        end
      end
    end

    context "when non-admin views a destroyed record version" do
      permissions :show?, :destroy? do
        it "denies access" do
          is_expected.not_to permit(user, version)
        end
      end
    end
  end

  describe "Scope" do
    def resolve_scope
      described_class::Scope.new(user, PaperTrail::Version).resolve
    end

    context "when user is admin" do
      let(:user) { create(:user, :admin) }

      it "includes all versions" do
        expect(resolve_scope).to include(version)
      end
    end

    context "when user can view the versioned resource" do
      before do
        create(:user_association, user: user, associable: lease.property.owner)
      end

      it "includes versions for viewable resources" do
        expect(resolve_scope).to include(version)
      end
    end

    context "when user cannot view the versioned resource" do
      it "excludes versions for non-viewable resources" do
        expect(resolve_scope).not_to include(version)
      end
    end
  end
end
