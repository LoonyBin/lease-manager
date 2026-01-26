require 'rails_helper'

RSpec.describe "Properties", type: :request do
  describe "GET /properties" do
    it "returns http success" do
      get properties_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /properties" do
    context "with valid parameters" do
      let(:valid_attributes) { { name: "Sunset Villa", address: "123 Sunset Blvd" } }

      it "creates a new Property" do
        expect {
          post properties_path, params: { property: valid_attributes }
        }.to change(Property, :count).by(1)
      end

      it "redirects to the created property" do
        post properties_path, params: { property: valid_attributes }
        expect(response).to redirect_to(property_path(Property.last))
      end
    end

    context "with invalid parameters" do
      it "does not create a new Property" do
        expect {
          post properties_path, params: { property: { name: "" } }
        }.to change(Property, :count).by(0)
      end

      it "renders the new template" do
        post properties_path, params: { property: { name: "" } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "GET /properties/:id" do
    let!(:property) { create(:property) }

    it "returns http success" do
      get property_path(property)
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /properties/:id/edit" do
    let!(:property) { create(:property) }

    it "returns http success" do
      get edit_property_path(property)
      expect(response).to have_http_status(:success)
    end
  end

  describe "PATCH /properties/:id" do
    let!(:property) { create(:property) }
    let(:new_attributes) { { name: "Ocean View" } }

    context "with valid parameters" do
      it "updates the requested property" do
        patch property_path(property), params: { property: new_attributes }
        property.reload
        expect(property.name).to eq("Ocean View")
      end

      it "redirects to the property" do
        patch property_path(property), params: { property: new_attributes }
        expect(response).to redirect_to(property)
      end
    end

    context "with invalid parameters" do
      it "renders the edit template" do
        patch property_path(property), params: { property: { name: "" } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "DELETE /properties/:id" do
    let!(:property) { create(:property) }

    it "destroys the requested property" do
      expect {
        delete property_path(property)
      }.to change(Property, :count).by(-1)
    end

    it "redirects to the properties list" do
      delete property_path(property)
      expect(response).to redirect_to(properties_url)
    end
  end
end
