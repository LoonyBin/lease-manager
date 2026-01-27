# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Leases" do
  let(:property) { create(:property) }
  let(:tenant) { create(:tenant) }

  describe "GET /leases" do
    it "returns http success" do
      get leases_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /leases/new" do
    it "returns http success" do
      get new_lease_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /leases" do
    context "with valid parameters" do
      let(:valid_attributes) do
        {
          property_id: property.id,
          tenant_id: tenant.id,
          start_date: "2025-01-01",
          duration_months: 12,
          rent_amount: 1000.0,
          security_deposit_in_months: 2,
          enhancement_period_months: 12,
          enhancement_amount: "5.0",
          enhancement_type: "percentage"
        }
      end

      it "creates a new Lease" do
        expect do
          post leases_path, params: { lease: valid_attributes }
        end.to change(Lease, :count).by(1)
      end

      it "redirects to the created lease" do
        post leases_path, params: { lease: valid_attributes }
        expect(response).to redirect_to(lease_path(Lease.last))
      end
    end

    context "with invalid parameters" do
      it "does not create a new Lease" do
        expect do
          post leases_path, params: { lease: { rent_amount: "" } }
        end.not_to change(Lease, :count)
      end
    end
  end
end
