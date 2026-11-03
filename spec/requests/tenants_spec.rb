# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Tenants" do
  before { sign_in_admin }

  describe "GET /tenants" do
    it "returns http success" do
      get tenants_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /tenants/:id" do
    let!(:tenant) { create(:tenant) }

    it "returns http success" do
      get tenant_path(tenant)
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /tenants/new" do
    it "returns http success" do
      get new_tenant_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /tenants/:id/edit" do
    let!(:tenant) { create(:tenant) }

    it "returns http success" do
      get edit_tenant_path(tenant)
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /tenants" do
    context "with valid parameters" do
      let(:valid_attributes) { { name: "John Doe", email: "john@example.com", phone_number: "555-0123" } }

      it "creates a new Tenant" do
        expect do
          post tenants_path, params: { tenant: valid_attributes }
        end.to change(Tenant, :count).by(1)
      end

      it "redirects to the created tenant" do
        post tenants_path, params: { tenant: valid_attributes }
        expect(response).to redirect_to(tenant_path(Tenant.last))
      end
    end

    context "with invalid parameters" do
      it "does not create a new Tenant" do
        expect do
          post tenants_path, params: { tenant: { name: "" } }
        end.not_to change(Tenant, :count)
      end

      it "renders the new template" do
        post tenants_path, params: { tenant: { name: "" } }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "PATCH /tenants/:id" do
    let!(:tenant) { create(:tenant) }
    let(:new_attributes) { { name: "Jane Doe" } }

    context "with valid parameters" do
      it "updates the requested tenant" do
        patch tenant_path(tenant), params: { tenant: new_attributes }
        tenant.reload
        expect(tenant.name).to eq("Jane Doe")
      end

      it "redirects to the tenant" do
        patch tenant_path(tenant), params: { tenant: new_attributes }
        expect(response).to redirect_to(tenant)
      end
    end

    context "with invalid parameters" do
      it "renders the edit template" do
        patch tenant_path(tenant), params: { tenant: { name: "" } }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "DELETE /tenants/:id" do
    let!(:tenant) { create(:tenant) }

    it "destroys the requested tenant" do
      expect do
        delete tenant_path(tenant)
      end.to change(Tenant, :count).by(-1)
    end

    it "redirects to the tenants list" do
      delete tenant_path(tenant)
      expect(response).to redirect_to(tenants_url)
    end
  end

  describe "JSON via API token" do
    it_behaves_like "serves JSON with a valid API token" do
      let(:json_path) { tenants_path(format: :json) }
    end

    it_behaves_like "serves JSON with a valid API token" do
      let(:json_path) { tenant_path(create(:tenant), format: :json) }
    end
  end
end
