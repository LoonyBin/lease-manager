# frozen_string_literal: true

require "rails_helper"

RSpec.describe "UserAssociations" do
  describe "POST /user_associations" do
    let(:user) { create(:user) }
    let(:owner) { create(:owner) }
    let(:tenant) { create(:tenant) }

    context "when logged in as admin" do
      before { sign_in_admin }

      it "creates a new owner association" do
        expect do
          post user_associations_path,
               params: { user_association: { user_id: user.id, associable_type: "Owner", associable_id: owner.id } }
        end.to change(UserAssociation, :count).by(1)
      end

      it "redirects to the owner after creating owner association" do
        post user_associations_path,
             params: { user_association: { user_id: user.id, associable_type: "Owner", associable_id: owner.id } }
        expect(response).to redirect_to(owner_path(owner))
      end

      it "associates the owner with the user" do
        post user_associations_path,
             params: { user_association: { user_id: user.id, associable_type: "Owner", associable_id: owner.id } }
        expect(user.reload.owners).to include(owner)
      end

      it "creates a new tenant association" do
        expect do
          post user_associations_path,
               params: { user_association: { user_id: user.id, associable_type: "Tenant", associable_id: tenant.id } }
        end.to change(UserAssociation, :count).by(1)
      end

      it "associates the tenant with the user" do
        post user_associations_path,
             params: { user_association: { user_id: user.id, associable_type: "Tenant", associable_id: tenant.id } }
        expect(user.reload.tenants).to include(tenant)
      end

      it "does not create a duplicate association" do
        create(:user_association, user: user, associable: owner)
        expect do
          post user_associations_path,
               params: { user_association: { user_id: user.id, associable_type: "Owner", associable_id: owner.id } }
        end.not_to change(UserAssociation, :count)
      end

      it "redirects with an error for duplicate association" do
        create(:user_association, user: user, associable: owner)
        post user_associations_path,
             params: { user_association: { user_id: user.id, associable_type: "Owner", associable_id: owner.id } }
        expect(response).to redirect_to(owner_path(owner))
      end

      it "sets an alert flash message for duplicate association" do
        create(:user_association, user: user, associable: owner)
        post user_associations_path,
             params: { user_association: { user_id: user.id, associable_type: "Owner", associable_id: owner.id } }
        expect(flash[:alert]).to be_present
      end
    end

    context "when logged in as normal user" do
      before do
        normal_user = create(:user, :normal)
        sign_in_as(normal_user)
      end

      it "denies access" do
        post user_associations_path,
             params: { user_association: { user_id: user.id, associable_type: "Owner", associable_id: owner.id } }
        expect(response).to redirect_to(root_path)
      end
    end

    context "when not logged in" do
      it "denies access" do
        post user_associations_path,
             params: { user_association: { user_id: user.id, associable_type: "Owner", associable_id: owner.id } }
        expect(response).to redirect_to(login_path)
      end
    end
  end

  describe "DELETE /user_associations/:id" do
    context "when logged in as admin" do
      before { sign_in_admin }

      let!(:user_association) { create(:user_association) }

      it "destroys the association" do
        expect do
          delete user_association_path(user_association)
        end.to change(UserAssociation, :count).by(-1)
      end

      it "redirects back" do
        delete user_association_path(user_association)
        expect(response).to redirect_to(root_path)
      end
    end

    context "when logged in as normal user" do
      before do
        normal_user = create(:user, :normal)
        sign_in_as(normal_user)
      end

      let!(:user_association) { create(:user_association) }

      it "denies access" do
        delete user_association_path(user_association)
        expect(response).to redirect_to(root_path)
      end
    end
  end
end
