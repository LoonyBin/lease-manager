# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Sessions" do
  describe "GET /login" do
    it "renders the login page", :aggregate_failures do
      get login_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Sign in with Google")
    end
  end
end
