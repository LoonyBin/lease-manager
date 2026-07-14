# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API rate limiting" do
  let(:user) { create(:user, :admin) }
  let(:api_token) { create(:api_token, user: user) }
  let(:headers) { { "Authorization" => "Bearer #{api_token.plaintext_token}" } }
  let(:limit) { Rails.configuration.x.api_rate_limit.limit }

  before { ApplicationController::API_RATE_LIMIT_STORE.clear }

  it "serves requests up to the limit" do
    limit.times { get properties_path(format: :json), headers: headers }
    expect(response).to have_http_status(:ok)
  end

  it "throttles requests past the limit" do
    (limit + 1).times { get properties_path(format: :json), headers: headers }
    expect(response).to have_http_status(:too_many_requests)
  end

  it "shares the counter across controllers" do
    limit.times { get properties_path(format: :json), headers: headers }
    get tenants_path(format: :json), headers: headers
    expect(response).to have_http_status(:too_many_requests)
  end

  it "counts each token separately" do
    other = create(:api_token, user: user)
    (limit + 1).times { get properties_path(format: :json), headers: headers }
    get properties_path(format: :json), headers: { "Authorization" => "Bearer #{other.plaintext_token}" }
    expect(response).to have_http_status(:ok)
  end

  it "throttles invalid tokens rather than only rejecting them" do
    (limit + 1).times { get properties_path(format: :json), headers: { "Authorization" => "Bearer wrong" } }
    expect(response).to have_http_status(:too_many_requests)
  end

  it "never throttles session requests" do
    sign_in_as(user)
    (limit + 1).times { get properties_path }
    expect(response).to have_http_status(:ok)
  end
end
