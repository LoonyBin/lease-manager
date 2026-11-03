# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Properties" do
  before { sign_in_admin }

  describe "GET /properties" do
    it "returns http success" do
      get properties_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /properties" do
    context "with valid parameters" do
      let(:owner) { create(:owner) }
      let(:valid_attributes) do
        { name: "Sunset Villa", address: "123 Sunset Blvd", owner_id: owner.id, capacity: 10, unit: "Rooms" }
      end

      it "creates a new Property" do
        expect do
          post properties_path, params: { property: valid_attributes }
        end.to change(Property, :count).by(1)
      end

      it "redirects to the created property" do
        post properties_path, params: { property: valid_attributes }
        expect(response).to redirect_to(property_path(Property.last))
      end
    end

    context "with invalid parameters" do
      it "does not create a new Property" do
        expect do
          post properties_path, params: { property: { name: "" } }
        end.not_to change(Property, :count)
      end

      it "renders the new template" do
        post properties_path, params: { property: { name: "" } }
        expect(response).to have_http_status(:unprocessable_content)
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
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "DELETE /properties/:id" do
    let!(:property) { create(:property) }

    it "destroys the requested property" do
      expect do
        delete property_path(property)
      end.to change(Property, :count).by(-1)
    end

    it "redirects to the properties list" do
      delete property_path(property)
      expect(response).to redirect_to(properties_url)
    end
  end

  describe "JSON via API token" do
    it_behaves_like "serves JSON with a valid API token" do
      let(:json_path) { properties_path(format: :json) }
    end

    it_behaves_like "serves JSON with a valid API token" do
      let(:json_path) { property_path(create(:property), format: :json) }
    end
  end

  describe "JSON mutations via API token" do
    let(:api_headers) do
      token = create(:api_token, user: create(:user, :admin))
      { "Authorization" => "Bearer #{token.plaintext_token}" }
    end
    let(:json_attributes) do
      { name: "API Villa", address: "9 API Way", owner_id: create(:owner).id, capacity: 4, unit: "Rooms" }
    end

    it "creates a property returning 201" do
      post properties_path(format: :json), params: { property: json_attributes }, headers: api_headers
      expect(response).to have_http_status(:created)
    end

    it "returns validation errors as JSON" do
      post properties_path(format: :json), params: { property: { name: "" } }, headers: api_headers
      expect(response.parsed_body["errors"]).to be_present
    end

    it "updates a property returning the record" do
      property = create(:property)
      patch property_path(property, format: :json), params: { property: { name: "Renamed" } }, headers: api_headers
      expect(response.parsed_body["name"]).to eq("Renamed")
    end

    it "destroys a property returning 204" do
      property = create(:property)
      delete property_path(property, format: :json), headers: api_headers
      expect(response).to have_http_status(:no_content)
    end
  end
end
