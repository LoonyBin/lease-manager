# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Reports" do
  let(:user) { create(:user) }
  let(:admin) { create(:user, :admin) }

  describe "GET /reports" do
    context "when unauthenticated" do
      it "redirects to login" do
        get reports_path
        expect(response).to redirect_to(login_path)
      end
    end

    context "when authenticated as normal user" do
      before do
        sign_in_as(user)
        get reports_path
      end

      it { expect(response).to have_http_status(:success) }
      it { expect(response.body).to include("Financial Dashboard") }
    end

    context "when authenticated as admin" do
      before do
        sign_in_admin
      end

      it "returns http success" do
        get reports_path
        expect(response).to have_http_status(:success)
      end
    end
  end
end
