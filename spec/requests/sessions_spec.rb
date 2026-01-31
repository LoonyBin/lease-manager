# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Sessions" do
  before do
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:developer] = OmniAuth::AuthHash.new(
      provider: "developer",
      uid: "test-uid",
      info: {
        email: "test@example.com",
        name: "Test User"
      }
    )
  end

  after do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:developer] = nil
  end

  describe "GET /auth/developer/callback" do
    it "creates a new user if one does not exist" do
      expect do
        get "/auth/developer/callback"
      end.to change(User, :count).by(1)
    end

    it "does not create a user if one already exists" do
      create(:user, provider: "developer", uid: "test-uid")
      expect do
        get "/auth/developer/callback"
      end.not_to change(User, :count)
    end

    it "sets the session user_id" do
      get "/auth/developer/callback"
      expect(session[:user_id]).to eq(User.last.id)
    end

    it "redirects to root path" do
      get "/auth/developer/callback"
      expect(response).to redirect_to(root_path)
    end

    it "displays success notice" do
      get "/auth/developer/callback"
      follow_redirect!
      expect(response.body).to include("Signed in successfully")
    end
  end

  describe "DELETE /logout" do
    before do
      get "/auth/developer/callback"
    end

    it "clears the session user_id" do
      delete logout_path
      expect(session[:user_id]).to be_nil
    end

    it "redirects to root path" do
      delete logout_path
      expect(response).to redirect_to(root_path)
    end

    it "sets success notice" do
      delete logout_path
      expect(flash[:notice]).to eq("Signed out successfully.")
    end
  end
end
