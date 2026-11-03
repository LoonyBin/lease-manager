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

      # The scope resolves a policy scope per tracked item_type. A model with no
      # policy scope resolved to nil and took the whole index down with it.
      it "returns http success when a version belongs to a controllerless model" do
        create(:payment, lease: lease)

        get versions_path

        expect(response).to have_http_status(:success)
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

  # PaperTrail tracks every ApplicationRecord, but only some of them are
  # reachable by a GET. The header "view the record" link used to call
  # polymorphic_path unconditionally, so a version of a routeless model raised
  # NoMethodError for the missing path helper and the whole page 500ed.
  describe "GET /versions/:id for item types without a show route" do
    before { sign_in_admin }

    context "with a routable item" do
      let(:lease) { create(:lease) }

      before { get version_path(lease.versions.last) }

      it "returns http success" do
        expect(response).to have_http_status(:success)
      end

      it "links to the record" do
        expect(response.body).to include(lease_path(lease))
      end
    end

    context "with a nested item excluded from :show" do
      let(:reminder_step) { create(:reminder_step) }

      before { get version_path(reminder_step.versions.last) }

      it "returns http success" do
        expect(response).to have_http_status(:success)
      end

      it "still renders the diff table" do
        expect(response.body).to include("ReminderStep")
      end
    end

    context "with an index-only item" do
      let(:notification) { create(:invoice_notification) }

      it "returns http success" do
        get version_path(notification.versions.last)

        expect(response).to have_http_status(:success)
      end
    end

    context "with an item that has no routes at all" do
      let(:entry) { create(:payment).lease.entries.last }

      it "returns http success" do
        get version_path(entry.versions.last)

        expect(response).to have_http_status(:success)
      end
    end

    # UserAssociation and ApiToken only route `destroy`, so the path helper
    # exists and builds a URL that answers nothing but DELETE. Linking there
    # would hand the user a dead link rather than a 500.
    context "when the path helper only answers DELETE" do
      let(:association) { create(:user_association) }

      before { get version_path(association.versions.last) }

      it "returns http success" do
        expect(response).to have_http_status(:success)
      end

      it "omits the link" do
        expect(response.body).not_to include(%(href="/user_associations/#{association.id}"))
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

  describe "JSON via API token" do
    it_behaves_like "serves JSON with a valid API token" do
      let(:json_path) { versions_path(format: :json) }
    end

    it_behaves_like "serves JSON with a valid API token" do
      let(:json_path) do
        create(:property)
        version_path(Version.last, format: :json)
      end
    end
  end
end
