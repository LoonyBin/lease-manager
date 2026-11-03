# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Users" do
  before { sign_in_admin }

  describe "GET /users" do
    it "returns http success" do
      get users_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /users/:id" do
    let!(:user) { create(:user) }

    it "returns http success" do
      get user_path(user)
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /users/new" do
    it "returns http success" do
      get new_user_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /users/:id/edit" do
    let!(:user) { create(:user) }

    it "returns http success" do
      get edit_user_path(user)
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /users" do
    context "with valid parameters" do
      let(:valid_attributes) { { uid: "new-uid", provider: "developer", name: "New User", email: "new@example.com" } }

      it "creates a new User" do
        expect do
          post users_path, params: { user: valid_attributes }
        end.to change(User, :count).by(1)
      end

      it "redirects to the created user" do
        post users_path, params: { user: valid_attributes }
        expect(response).to redirect_to(user_path(User.last))
      end
    end

    context "with invalid parameters" do
      it "does not create a new User" do
        expect do
          post users_path, params: { user: { uid: "" } }
        end.not_to change(User, :count)
      end

      it "renders the new template" do
        post users_path, params: { user: { uid: "" } }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "PATCH /users/:id" do
    let!(:user) { create(:user) }
    let(:new_attributes) { { name: "Updated Name" } }

    context "with valid parameters" do
      it "updates the requested user" do
        patch user_path(user), params: { user: new_attributes }
        user.reload
        expect(user.name).to eq("Updated Name")
      end

      it "redirects to the user" do
        patch user_path(user), params: { user: new_attributes }
        expect(response).to redirect_to(user)
      end
    end

    context "with invalid parameters" do
      it "renders the edit template" do
        patch user_path(user), params: { user: { uid: "" } }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "DELETE /users/:id" do
    let!(:user) { create(:user) }

    it "destroys the requested user" do
      expect do
        delete user_path(user)
      end.to change(User, :count).by(-1)
    end

    it "redirects to the users list" do
      delete user_path(user)
      expect(response).to redirect_to(users_url)
    end
  end

  describe "JSON via API token" do
    it_behaves_like "serves JSON with a valid API token" do
      let(:json_path) { users_path(format: :json) }
    end

    it_behaves_like "serves JSON with a valid API token" do
      let(:json_path) { user_path(create(:user), format: :json) }
    end
  end
end
