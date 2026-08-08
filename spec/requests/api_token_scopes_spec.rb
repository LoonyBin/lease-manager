# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API token scopes" do
  # An admin user proves the gate is credential-level, not permission-level:
  # a token whose user may write everything still cannot write when read_only.
  let(:user) { create(:user, :admin) }
  let(:read_only_token) { create(:api_token, :read_only, user: user) }
  let(:read_write_token) { create(:api_token, user: user) }
  let(:property) { create(:property) }

  # Methods, not lets, to stay under RSpec/MultipleMemoizedHelpers.
  def ro_headers
    { "Authorization" => "Bearer #{read_only_token.plaintext_token}" }
  end

  def rw_headers
    { "Authorization" => "Bearer #{read_write_token.plaintext_token}" }
  end

  def property_attributes
    { name: "Villa", address: "1 API St", owner_id: create(:owner).id, capacity: 2, unit: "Rooms" }
  end

  describe "a read_only token" do
    it "allows GET index" do
      get properties_path(format: :json), headers: ro_headers
      expect(response).to have_http_status(:ok)
    end

    it "allows GET show" do
      get property_path(property, format: :json), headers: ro_headers
      expect(response).to have_http_status(:ok)
    end

    it "rejects POST with 403 and an error body", :aggregate_failures do
      post properties_path(format: :json), params: { property: property_attributes }, headers: ro_headers
      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body).to include("error")
    end

    it "rejects PATCH with 403" do
      patch property_path(property, format: :json), params: { property: { name: "Renamed" } }, headers: ro_headers
      expect(response).to have_http_status(:forbidden)
    end

    it "rejects PUT with 403" do
      put property_path(property, format: :json), params: { property: { name: "Renamed" } }, headers: ro_headers
      expect(response).to have_http_status(:forbidden)
    end

    it "rejects DELETE with 403" do
      delete property_path(property, format: :json), headers: ro_headers
      expect(response).to have_http_status(:forbidden)
    end
  end

  # The 403 must fire before the action, so the *side effect* is blocked, not
  # merely the response — the actual harm the issue names.
  describe "the block prevents the side effect, not just the response" do
    # Create the record and the token/user up front so their audit versions
    # predate the measured block below.
    before do
      property
      ro_headers
    end

    it "leaves the record and writes no audit version for a blocked DELETE", :aggregate_failures do
      expect { delete property_path(property, format: :json), headers: ro_headers }
        .not_to change(PaperTrail::Version, :count)
      expect(response).to have_http_status(:forbidden)
      expect(Property.exists?(property.id)).to be(true)
    end
  end

  describe "blocked reminder approvals send no mail" do
    let(:notification) { create(:invoice_notification, invoice: create(:invoice, status: :finalized)) }

    before { notification }

    it "denies approve without enqueuing a send or leaving pending", :aggregate_failures do
      expect { patch approve_invoice_notification_path(notification, format: :json), headers: ro_headers }
        .not_to have_enqueued_job(SendInvoiceNotificationJob)
      expect(response).to have_http_status(:forbidden)
      expect(notification.reload).to be_pending
    end

    it "denies approve_all without enqueuing a send or touching pending rows", :aggregate_failures do
      expect { patch approve_all_invoice_notifications_path(format: :json), headers: ro_headers }
        .not_to have_enqueued_job(SendInvoiceNotificationJob)
      expect(response).to have_http_status(:forbidden)
      expect(notification.reload).to be_pending
    end
  end

  # The regression most likely to reappear: a token request must never fall
  # back to the browser session, so a read_only token wins even with a live,
  # write-capable session on the same request.
  describe "session-vs-token boundary" do
    it "403s a write when a live session also carries a read_only bearer token", :aggregate_failures do
      sign_in_as(user)
      delete property_path(property, format: :json), headers: ro_headers
      expect(response).to have_http_status(:forbidden)
      expect(Property.exists?(property.id)).to be(true)
    end
  end

  describe "a read_write token" do
    it "still performs mutations" do
      post properties_path(format: :json), params: { property: property_attributes }, headers: rw_headers
      expect(response).to have_http_status(:created)
    end
  end

  describe "browser sessions" do
    it "are unaffected by scope (no Authorization header, so no gate)", :aggregate_failures do
      sign_in_as(user)
      expect { post properties_path, params: { property: property_attributes } }
        .to change(Property, :count).by(1)
      expect(response).to have_http_status(:redirect)
    end
  end
end
