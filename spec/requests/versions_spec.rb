# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Versions" do
  describe "GET /versions" do
    context "when admin" do
      before { sign_in_admin }

      it "returns http success" do
        create(:lease)
        get versions_path
        expect(response).to have_http_status(:success)
      end
    end

    context "when normal user with viewable resources" do
      let(:user) { create(:user) }
      let(:lease) { create(:lease) }

      before do
        create(:user_association, user: user, associable: lease.property.owner)
        lease.update!(rent_amount: lease.rent_amount + 1000)
        sign_in_as(user)
      end

      it "returns http success" do
        get versions_path
        expect(response).to have_http_status(:success)
      end

      it "shows versions for viewable resources" do
        get versions_path
        expect(response.body).to include(lease.class.name)
      end
    end
  end

  describe "GET /versions/:id" do
    let(:lease) { create(:lease) }
    let(:version) { lease.versions.last }

    context "when admin" do
      before { sign_in_admin }

      it "returns http success" do
        get version_path(version)
        expect(response).to have_http_status(:success)
      end
    end

    context "when user can view the versioned resource" do
      let(:user) { create(:user) }

      before do
        create(:user_association, user: user, associable: lease.property.owner)
        sign_in_as(user)
      end

      it "returns http success" do
        get version_path(version)
        expect(response).to have_http_status(:success)
      end
    end

    context "when user cannot view the versioned resource" do
      let(:user) { create(:user) }

      before { sign_in_as(user) }

      it "redirects with unauthorized message" do
        get version_path(version)
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "DELETE /versions/:id" do
    let(:lease) { create(:lease) }
    let(:version) { lease.versions.last }

    context "when admin" do
      before { sign_in_admin }

      it "destroys the version" do
        version_id = version.id
        expect { delete version_path(version_id) }.to change(PaperTrail::Version, :count).by(-1)
      end

      it "redirects to versions index" do
        delete version_path(version)
        expect(response).to redirect_to(versions_path)
      end
    end

    context "when non-admin user" do
      let(:user) { create(:user) }

      before do
        create(:user_association, user: user, associable: lease.property.owner)
        sign_in_as(user)
      end

      it "denies access" do
        delete version_path(version)
        expect(response).to redirect_to(root_path)
      end
    end
  end
end
