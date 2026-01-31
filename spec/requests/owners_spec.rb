# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Owners" do
  before { sign_in_admin }

  let!(:owner) { create(:owner) }
  let(:valid_attributes) { { name: "New Owner", address: "123 Main St" } }
  let(:invalid_attributes) { { name: "" } }

  describe "GET /index" do
    it "returns http success" do
      get owners_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /show" do
    it "returns http success" do
      get owner_path(owner)
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /new" do
    it "returns http success" do
      get new_owner_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /edit" do
    it "returns http success" do
      get edit_owner_path(owner)
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /create" do
    context "with valid parameters" do
      it "creates a new Owner" do
        expect do
          post owners_path, params: { owner: valid_attributes }
        end.to change(Owner, :count).by(1)
      end

      it "redirects to the created owner" do
        post owners_path, params: { owner: valid_attributes }
        expect(response).to redirect_to(owner_path(Owner.last))
      end
    end

    context "with invalid parameters" do
      it "does not create a new Owner" do
        expect do
          post owners_path, params: { owner: invalid_attributes }
        end.not_to change(Owner, :count)
      end

      it "renders a response with 422 status" do
        post owners_path, params: { owner: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "PATCH /update" do
    context "with valid parameters" do
      let(:new_attributes) { { name: "Updated Name" } }

      it "updates the requested owner" do
        patch owner_path(owner), params: { owner: new_attributes }
        owner.reload
        expect(owner.name).to eq("Updated Name")
      end

      it "redirects to the owner" do
        patch owner_path(owner), params: { owner: new_attributes }
        expect(response).to redirect_to(owner_path(owner))
      end
    end

    context "with invalid parameters" do
      it "renders a response with 422 status" do
        patch owner_path(owner), params: { owner: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "DELETE /destroy" do
    it "destroys the requested owner" do
      expect do
        delete owner_path(owner)
      end.to change(Owner, :count).by(-1)
    end

    it "redirects to the owners list" do
      delete owner_path(owner)
      expect(response).to redirect_to(owners_path)
    end
  end
end
