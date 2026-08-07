# frozen_string_literal: true

require "rails_helper"

# End-to-end coverage for the Ransack lockdown (#173). Two jobs:
#   1. Prove the api_tokens.token_digest oracle is closed on /users (AC#2).
#   2. Prove every association traversal / sort / cross-page link still works
#      under the narrowed allowlists. Ransack silently drops a non-allowlisted
#      condition or sort (no error), so a broken lockdown would otherwise sail
#      through as a green 200 — these specs assert the result set actually
#      narrows or reorders, which is the only thing that can catch a silent drop.
RSpec.describe "Ransack search" do
  before { sign_in_admin }

  describe "GET /users (token_digest oracle closed — AC#2)" do
    let!(:target) { create(:user, name: "ZZ-Oracle-Target") }
    let!(:token) { create(:api_token, user: target) }

    # A real digest prefix vs a deliberately wrong one. If the predicate still
    # discriminated, the wrong prefix would drop the target from the result set.
    let(:real_prefix) { token.token_digest[0, 8] }
    let(:wrong_prefix) { "#{real_prefix[0] == '0' ? '1' : '0'}#{real_prefix[1..]}" }

    before { create(:user, name: "ZZ-Oracle-Bystander") }

    def body_for(prefix)
      get users_path, params: { q: { api_tokens_token_digest_start: prefix } }
      response.body
    end

    it "returns the same users whether the digest prefix matches or not", :aggregate_failures do
      expect(body_for(real_prefix)).to include("ZZ-Oracle-Target", "ZZ-Oracle-Bystander")
      expect(body_for(wrong_prefix)).to include("ZZ-Oracle-Target", "ZZ-Oracle-Bystander")
    end
  end

  describe "GET /invoices (lease traversal still works)" do
    let!(:match) { create(:invoice, lease: create(:lease, tenant: create(:tenant, name: "ZZ-InvTenantMatch"))) }
    let!(:other) { create(:invoice, lease: create(:lease, tenant: create(:tenant, name: "ZZ-InvTenantOther"))) }

    it "filters on lease→tenant name", :aggregate_failures do
      get invoices_path, params: { q: { lease_tenant_name_cont: "ZZ-InvTenantMatch" } }
      expect(response.body).to include("ZZ-InvTenantMatch")
      expect(response.body).not_to include("ZZ-InvTenantOther")
    end

    it "sorts on lease→property name without dropping the sort node" do
      match.lease.property.update!(name: "AAA-InvProp")
      other.lease.property.update!(name: "ZZZ-InvProp")
      get invoices_path, params: { q: { s: "lease_property_name asc" } }
      expect(response.body.index("AAA-InvProp")).to be < response.body.index("ZZZ-InvProp")
    end
  end

  describe "GET /payments" do
    let(:lease) { create(:lease, tenant: create(:tenant, name: "ZZ-PayTenant")) }
    let!(:older) do
      create(:payment, lease: lease, date: Date.new(2025, 3, 1),
                       reference_number: "ZZ-PAY-OLDER", created_at: 2.days.ago)
    end

    before do
      create(:payment, lease: lease, date: Date.new(2025, 3, 1),
                       reference_number: "ZZ-PAY-NEWER", created_at: 1.day.ago)
    end

    # payments_controller defaults @q.sorts to ["date desc", "created_at desc"];
    # without created_at in the allowlist the tiebreak is silently dropped and
    # same-date ordering becomes nondeterministic. Regression guard for §2 of #173.
    it "breaks same-date ties by created_at desc" do
      get payments_path
      expect(response.body.index("ZZ-PAY-NEWER")).to be < response.body.index("ZZ-PAY-OLDER")
    end

    it "filters by id_in (the invoices/show 'View payments' link)", :aggregate_failures do
      get payments_path, params: { q: { id_in: [older.id] } }
      expect(response.body).to include("ZZ-PAY-OLDER")
      expect(response.body).not_to include("ZZ-PAY-NEWER")
    end
  end

  describe "GET /leases (property/tenant traversal + scope)" do
    before do
      create(:lease, property: create(:property, name: "ZZ-LeaseActive"))
      create(:lease, property: create(:property, name: "ZZ-LeaseTerm"),
                     start_date: Date.new(2025, 1, 1), terminated_on: Date.new(2025, 2, 1))
    end

    it "filters on property name", :aggregate_failures do
      get leases_path, params: { q: { property_name_cont: "ZZ-LeaseActive" } }
      expect(response.body).to include("ZZ-LeaseActive")
      expect(response.body).not_to include("ZZ-LeaseTerm")
    end

    it "applies the by_status ransackable scope", :aggregate_failures do
      get leases_path, params: { q: { by_status: "terminated" } }
      expect(response.body).to include("ZZ-LeaseTerm")
      expect(response.body).not_to include("ZZ-LeaseActive")
    end
  end

  describe "GET /invoice_notifications (invoice→lease→tenant traversal)" do
    before do
      %w[ZZ-NotifMatch ZZ-NotifOther].each do |tenant_name|
        lease = create(:lease, tenant: create(:tenant, name: tenant_name))
        create(:invoice_notification, invoice: create(:invoice, lease: lease))
      end
    end

    it "filters on invoice→lease→tenant name", :aggregate_failures do
      get invoice_notifications_path, params: { q: { invoice_lease_tenant_name_cont: "ZZ-NotifMatch" } }
      expect(response.body).to include("ZZ-NotifMatch")
      expect(response.body).not_to include("ZZ-NotifOther")
    end
  end

  describe "GET /properties (owner_id cross-page link)" do
    let!(:match) { create(:property, name: "ZZ-PropMatch", owner: create(:owner, name: "ZZ-OwnerA")) }

    before { create(:property, name: "ZZ-PropOther", owner: create(:owner, name: "ZZ-OwnerB")) }

    it "filters by owner_id", :aggregate_failures do
      get properties_path, params: { q: { owner_id_eq: match.owner_id } }
      expect(response.body).to include("ZZ-PropMatch")
      expect(response.body).not_to include("ZZ-PropOther")
    end
  end
end
