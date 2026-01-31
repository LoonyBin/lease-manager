# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Payments" do
  before { sign_in_admin }

  let(:lease) { create(:lease) }

  describe "GET /payments" do
    it "returns http success" do
      get payments_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /payments/new" do
    it "returns http success" do
      get new_payment_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /payments" do
    context "with valid parameters" do
      let(:valid_params) do
        {
          payment: {
            lease_id: lease.id,
            amount: "100.00",
            date: Time.zone.today
          }
        }
      end

      it "creates a new Payment" do
        expect do
          post payments_path, params: valid_params
        end.to change(Payment, :count).by(1)
      end

      it "redirects to the payments list" do
        post payments_path, params: valid_params
        expect(response).to redirect_to(payments_path)
      end
    end

    context "with invalid parameters" do
      let(:invalid_params) do
        {
          payment: {
            lease_id: lease.id,
            amount: "", # invalid
            date: Time.zone.today
          }
        }
      end

      it "does not create a new Payment" do
        expect do
          post payments_path, params: invalid_params
        end.not_to change(Payment, :count)
      end

      it "renders a response with 422 status" do
        post payments_path, params: invalid_params
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end
end
