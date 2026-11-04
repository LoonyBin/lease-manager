# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Invoice audit visibility" do
  let(:today) { Date.current }
  let(:data) { build_audit_data }
  let(:payload) { response.parsed_body }

  def build_lease(owner, name, tenant: create(:tenant), templates: true, **attrs)
    property = create(:property, owner:, name: "#{name} Property")
    tenant.update!(name: "#{name} Tenant")
    attrs = { start_date: today - 2.months, duration_months: 12 }.merge(attrs)
    create(:lease, property:, tenant:, **attrs).tap { |lease| lease.invoice_templates.destroy_all unless templates }
  end

  def build_audit_data
    owner_a = create(:owner)
    tenant_a = create(:tenant)
    {
      owner_a:, tenant_a:,
      own: build_lease(owner_a, "OwnMissing", tenant: tenant_a),
      own_bare: build_lease(owner_a, "OwnBare", templates: false),
      other: build_lease(create(:owner), "OtherMissing"),
      other_bare: build_lease(create(:owner), "OtherBare", templates: false)
    }.merge(build_ineligible_leases(owner_a), build_terminated_lease(owner_a))
  end

  def build_ineligible_leases(owner)
    ended = { terminated_on: today - 1.month, archived_at: today }
    {
      archived: build_lease(owner, "OwnArchived", **ended),
      archived_bare: build_lease(owner, "OwnArchivedBare", templates: false, **ended),
      upcoming: build_lease(owner, "OwnUpcoming", templates: false, start_date: today + 3.months),
      expired: build_lease(owner, "OwnExpired", start_date: today - 30.months)
    }
  end

  def build_terminated_lease(owner)
    { terminated: build_lease(owner, "OwnTerminated", terminated_on: today - 1.month) }
  end

  def missing_ids
    payload["missing_invoices"].pluck("lease_id").uniq
  end

  def bare_ids
    payload["leases_without_templates"].pluck("id")
  end

  def associate(user, *parties)
    parties.each { |party| create(:user_association, user:, associable: party) }
    user
  end

  def audit_json(headers: {})
    get audit_invoices_path(format: :json), headers:
  end

  def bearer(token)
    { "Authorization" => "Bearer #{token.plaintext_token}" }
  end

  describe "as an admin" do
    before { data && sign_in_admin }

    it "lists every eligible lease in both lists", :aggregate_failures do
      audit_json
      expect(missing_ids).to include(data[:own].id, data[:other].id, data[:expired].id, data[:terminated].id)
      expect(bare_ids).to include(data[:own_bare].id, data[:other_bare].id)
    end

    it "leaves out archived and upcoming leases", :aggregate_failures do
      audit_json
      expect(missing_ids + bare_ids).not_to include(data[:archived].id, data[:archived_bare].id, data[:upcoming].id)
    end
  end

  describe "as an owner-associated user" do
    before do
      data
      sign_in_as(associate(create(:user), data[:owner_a]))
    end

    it "lists only the owner's eligible leases in JSON", :aggregate_failures do
      audit_json
      expect(missing_ids).to contain_exactly(data[:own].id, data[:expired].id, data[:terminated].id)
      expect(bare_ids).to contain_exactly(data[:own_bare].id)
    end

    it "keeps other parties out of the JSON body", :aggregate_failures do
      audit_json
      expect(response.body).not_to include("OtherMissing", "OtherBare")
      expect(response.body).not_to include("OwnArchived", "OwnUpcoming")
    end

    it "lists only the owner's leases in HTML", :aggregate_failures do
      get audit_invoices_path
      expect(response.body).to include("OwnMissing", "OwnBare")
      expect(response.body).not_to include("OtherMissing", "OtherBare", "OwnArchived", "OwnUpcoming")
    end
  end

  describe "as a tenant-associated user" do
    before do
      data
      sign_in_as(associate(create(:user), data[:tenant_a]))
    end

    it "lists only the tenant's own lease", :aggregate_failures do
      audit_json
      expect(missing_ids).to eq([data[:own].id])
      expect(response.body).not_to include("OtherMissing", "OtherBare")
    end

    it "renders only the tenant's own lease in HTML", :aggregate_failures do
      get audit_invoices_path
      expect(response.body).to include("OwnMissing")
      expect(response.body).not_to include("OtherMissing", "OtherBare")
    end
  end

  describe "as a user with both owner and tenant associations" do
    it "combines both branches and still excludes archived leases", :aggregate_failures do
      sign_in_as(associate(create(:user), data[:owner_a], data[:other].tenant))
      audit_json
      expect(missing_ids).to include(data[:own].id, data[:other].id)
      expect(missing_ids + bare_ids).not_to include(data[:archived].id, data[:upcoming].id, data[:other_bare].id)
    end
  end

  describe "as a user without associations" do
    before do
      data
      sign_in_user
    end

    it "returns empty lists in JSON", :aggregate_failures do
      audit_json
      expect(response).to have_http_status(:ok)
      expect(payload).to include("missing_invoices" => [], "leases_without_templates" => [])
    end

    it "renders no lease data in HTML", :aggregate_failures do
      get audit_invoices_path
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("OwnMissing", "OtherMissing", "OtherBare")
    end
  end

  describe "with an API token" do
    let(:audit_grant) { %w[invoices#audit] }

    def token_for(user, permissions: audit_grant, **traits)
      create(:api_token, :custom, *traits.keys, user:, permissions:)
    end

    before { data }

    it "gives an admin token the global view" do
      audit_json(headers: bearer(token_for(create(:user, :admin))))
      expect(missing_ids).to include(data[:own].id, data[:other].id)
    end

    it "limits a party token to its own leases", :aggregate_failures do
      audit_json(headers: bearer(token_for(associate(create(:user), data[:owner_a]))))
      expect(missing_ids).to include(data[:own].id)
      expect(response.body).not_to include("OtherMissing", "OtherBare")
    end

    it "returns empty lists for a token whose user has no associations", :aggregate_failures do
      audit_json(headers: bearer(token_for(create(:user))))
      expect(payload).to include("missing_invoices" => [], "leases_without_templates" => [])
    end

    it "refuses a token without the audit grant", :aggregate_failures do
      audit_json(headers: bearer(token_for(create(:user, :admin), permissions: %w[invoices#index])))
      expect(response).to have_http_status(:forbidden)
      expect(response.body).not_to include("OwnMissing", "OtherMissing")
    end

    it "rejects revoked and expired tokens even with a live session", :aggregate_failures do
      sign_in_admin
      %i[revoked expired].each do |trait|
        audit_json(headers: bearer(token_for(create(:user, :admin), trait => true)))
        expect(response).to have_http_status(:unauthorized)
      end
    end

    it "rejects an unknown token", :aggregate_failures do
      audit_json(headers: { "Authorization" => "Bearer lmt_wrong" })
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "without credentials" do
    it "turns anonymous callers away", :aggregate_failures do
      data
      audit_json
      expect(response).to have_http_status(:unauthorized)
      get audit_invoices_path
      expect(response).to redirect_to(login_path).or have_http_status(:found)
    end
  end

  describe "writes" do
    it "creates no invoices or line items", :aggregate_failures do
      data
      sign_in_as(associate(create(:user), data[:owner_a]))
      expect { audit_json }.not_to(change { [Invoice.count, LineItem.count] })
    end
  end
end
