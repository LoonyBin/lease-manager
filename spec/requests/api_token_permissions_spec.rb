# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API token permissions" do
  # An admin user proves the gate is credential-level, not permission-level: a
  # token whose user may do everything still cannot reach an action its
  # permission set omits.
  let(:user) { create(:user, :admin) }
  let(:read_only_token) { create(:api_token, :read_only, user: user) }
  let(:full_token) { create(:api_token, user: user) }
  let(:property) { create(:property) }

  # Methods, not lets, to stay under RSpec/MultipleMemoizedHelpers.
  def ro_headers
    { "Authorization" => "Bearer #{read_only_token.plaintext_token}" }
  end

  def full_headers
    { "Authorization" => "Bearer #{full_token.plaintext_token}" }
  end

  def token_headers(token)
    { "Authorization" => "Bearer #{token.plaintext_token}" }
  end

  def property_attributes
    { name: "Villa", address: "1 API St", owner_id: create(:owner).id, capacity: 2, unit: "Rooms" }
  end

  # The read-only preset reproduces the old read_only scope: safe reads pass,
  # every mutating verb is refused before the action runs.
  describe "a read-only preset token" do
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

    it "rejects DELETE with 403" do
      delete property_path(property, format: :json), headers: ro_headers
      expect(response).to have_http_status(:forbidden)
    end
  end

  # The issue's headline case: "read invoices, create payments, nothing else".
  describe "a custom token: invoices#index/show + payments#create only" do
    let(:custom_token) do
      create(:api_token, :custom, user: user,
                                  permissions: %w[invoices#index invoices#show payments#create])
    end

    it "allows GET invoices#index" do
      get invoices_path(format: :json), headers: token_headers(custom_token)
      expect(response).to have_http_status(:ok)
    end

    it "allows GET invoices#show" do
      get invoice_path(create(:invoice), format: :json), headers: token_headers(custom_token)
      expect(response).to have_http_status(:ok)
    end

    it "allows POST payments#create" do
      lease = create(:lease)
      post payments_path(format: :json),
           params: { payment: attributes_for(:payment, lease_id: lease.id) },
           headers: token_headers(custom_token)
      expect(response).to have_http_status(:created)
    end

    it "denies an ungranted read (payments#index) with the gate's body", :aggregate_failures do
      get payments_path(format: :json), headers: token_headers(custom_token)
      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body["error"]).to eq(I18n.t("authorization.token_action_forbidden"))
    end

    it "denies an ungranted write (invoices#update) and leaves the record", :aggregate_failures do
      invoice = create(:invoice)
      patch invoice_path(invoice, format: :json),
            params: { invoice: { status: "finalized" } }, headers: token_headers(custom_token)
      expect(response).to have_http_status(:forbidden)
      expect(invoice.reload).to be_draft
    end
  end

  # A token narrows and never widens: Pundit still runs afterwards. The token
  # here PERMITS the action (so the gate passes); Pundit is what refuses, with
  # Pundit's own body — proving the request reached the policy layer.
  describe "a token permitting an action its user may not perform" do
    let(:granted_token) do
      create(:api_token, :custom, user: create(:user), permissions: %w[properties#destroy])
    end

    it "still gets Pundit's refusal and does not destroy the record", :aggregate_failures do
      property
      delete property_path(property, format: :json), headers: token_headers(granted_token)
      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body["error"]).to eq(I18n.t("authorization.not_authorized"))
      expect(Property.exists?(property.id)).to be(true)
    end
  end

  # The 403 must fire before the action, so the *side effect* is blocked, not
  # merely the response — the actual harm the issue names.
  describe "the block prevents the side effect, not just the response" do
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

  # The regression most likely to reappear: a token request must never fall back
  # to the browser session, so a read-only token wins even with a live,
  # write-capable session on the same request.
  describe "session-vs-token boundary" do
    it "403s a write when a live session also carries a read-only bearer token", :aggregate_failures do
      sign_in_as(user)
      delete property_path(property, format: :json), headers: ro_headers
      expect(response).to have_http_status(:forbidden)
      expect(Property.exists?(property.id)).to be(true)
    end
  end

  # Nil-token fail-closed: the old verb guard allowed a nil token; the new guard
  # denies it. require_login catches nil everywhere it runs, so this surfaces
  # only where require_login is skipped (SessionsController). A stray/invalid
  # Authorization header on a session route is now 403, not a render.
  describe "a token request to a login route with an invalid bearer" do
    it "is fail-closed to 403 rather than rendering", :aggregate_failures do
      get login_path, headers: { "Authorization" => "Bearer lmt_not_a_real_token", "Accept" => "application/json" }
      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body["error"]).to eq(I18n.t("authorization.token_action_forbidden"))
    end
  end

  describe "browser sessions" do
    it "are unaffected by permissions (no Authorization header, so no gate)", :aggregate_failures do
      sign_in_as(user)
      expect { post properties_path, params: { property: property_attributes } }
        .to change(Property, :count).by(1)
      expect(response).to have_http_status(:redirect)
    end

    it "still renders the login page with no Authorization header" do
      get login_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "a full-access token" do
    it "still performs mutations" do
      post properties_path(format: :json), params: { property: property_attributes }, headers: full_headers
      expect(response).to have_http_status(:created)
    end
  end
end
