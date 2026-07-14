# frozen_string_literal: true

# Smoke test for the dual-format controllers: include with a `json_path`
# let pointing at the .json URL to fetch.
RSpec.shared_examples "serves JSON with a valid API token" do
  let(:json_api_headers) do
    token = create(:api_token, user: create(:user, :admin))
    { "Authorization" => "Bearer #{token.plaintext_token}" }
  end

  it "returns the resource as JSON" do
    get json_path, headers: json_api_headers
    expect(response.media_type).to eq("application/json")
  end

  it "responds with 200" do
    get json_path, headers: json_api_headers
    expect(response).to have_http_status(:ok)
  end
end
