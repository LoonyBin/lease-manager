# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Leases" do
  before { sign_in_admin }

  describe "GET /leases" do
    it "returns http success" do
      get leases_path
      expect(response).to have_http_status(:success)
    end

    context "when filtering by status" do
      let!(:active_lease) { create(:lease, start_date: 1.month.ago.to_date, duration_months: 12) }
      let!(:upcoming_lease) { create(:lease, start_date: 1.month.from_now.to_date, duration_months: 12) }
      let!(:expired_lease) { create(:lease, start_date: 2.years.ago.to_date, duration_months: 6) }
      let!(:terminated_lease) do
        create(:lease, start_date: 6.months.ago.to_date, duration_months: 12,
                       terminated_on: 3.months.ago.to_date)
      end
      let!(:archived_lease) do
        create(:lease, start_date: 8.months.ago.to_date, duration_months: 12,
                       terminated_on: 5.months.ago.to_date, archived_at: 4.months.ago)
      end

      it "returns only active leases when filtered by active", :aggregate_failures do
        get leases_path, params: { q: { by_status: "active" } }
        expect(response.body).to include(lease_path(active_lease))
        expect(response.body).not_to include(lease_path(upcoming_lease))
        expect(response.body).not_to include(lease_path(expired_lease))
        expect(response.body).not_to include(lease_path(terminated_lease))
      end

      it "returns only upcoming leases when filtered by upcoming", :aggregate_failures do
        get leases_path, params: { q: { by_status: "upcoming" } }
        expect(response.body).to include(lease_path(upcoming_lease))
        expect(response.body).not_to include(lease_path(active_lease))
        expect(response.body).not_to include(lease_path(expired_lease))
        expect(response.body).not_to include(lease_path(terminated_lease))
      end

      it "returns only expired leases when filtered by expired", :aggregate_failures do
        get leases_path, params: { q: { by_status: "expired" } }
        expect(response.body).to include(lease_path(expired_lease))
        expect(response.body).not_to include(lease_path(active_lease))
        expect(response.body).not_to include(lease_path(upcoming_lease))
        expect(response.body).not_to include(lease_path(terminated_lease))
      end

      it "returns only terminated leases when filtered by terminated", :aggregate_failures do
        get leases_path, params: { q: { by_status: "terminated" } }
        expect(response.body).to include(lease_path(terminated_lease))
        expect(response.body).not_to include(lease_path(active_lease), lease_path(upcoming_lease),
                                             lease_path(expired_lease), lease_path(archived_lease))
      end

      it "returns only archived leases when filtered by archived", :aggregate_failures do
        get leases_path, params: { q: { by_status: "archived" } }
        expect(response.body).to include(lease_path(archived_lease))
        expect(response.body).not_to include(lease_path(active_lease))
        expect(response.body).not_to include(lease_path(upcoming_lease))
        expect(response.body).not_to include(lease_path(terminated_lease))
      end
    end

    context "when no status filter is set" do
      let!(:active_lease) { create(:lease, start_date: 1.month.ago.to_date, duration_months: 12) }
      let!(:archived_lease) do
        create(:lease, start_date: 8.months.ago.to_date, duration_months: 12,
                       terminated_on: 5.months.ago.to_date, archived_at: 4.months.ago)
      end

      it "excludes archived leases by default", :aggregate_failures do
        get leases_path
        expect(response.body).to include(lease_path(active_lease))
        expect(response.body).not_to include(lease_path(archived_lease))
      end
    end
  end

  describe "GET /leases/new" do
    it "returns http success" do
      get new_lease_path
      expect(response).to have_http_status(:success)
    end

    context "when renewing" do
      let(:old_lease) { create(:lease) }

      it "returns success for renewal" do
        get new_lease_path(renewed_from_id: old_lease.id)
        expect(response).to have_http_status(:success)
      end

      it "pre-fills lease form with renewal defaults" do
        get new_lease_path(renewed_from_id: old_lease.id)
        expect(response.body).to include("Renewing lease ##{old_lease.id}")
      end
    end

    context "with property_id pre-populated" do
      let(:property) { create(:property) }

      it "returns success with readonly property field", :aggregate_failures do
        get new_lease_path(lease: { property_id: property.id })
        expect(response).to have_http_status(:success)
        expect(response.body).to include(CGI.escapeHTML(property.name))
      end
    end
  end

  describe "POST /leases" do
    let(:property) { create(:property) }
    let(:tenant) { create(:tenant) }

    context "with valid parameters" do
      let(:valid_attributes) do
        {
          property_id: property.id,
          tenant_id: tenant.id,
          start_date: "2025-01-01",
          duration_months: 12,
          rent_amount: 1000.0,
          security_deposit_value: 2,
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

      it "attaches documents" do
        file = fixture_file_upload("spec/fixtures/files/document.pdf", "application/pdf")
        post leases_path, params: { lease: valid_attributes.merge(documents: [file]) }
        expect(Lease.last.documents).to be_attached
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

  describe "PATCH /leases/:id" do
    let(:lease) { create(:lease) }

    context "when terminating" do
      let(:termination_date) { lease.start_date + 1.month }

      it "updates the terminated_on date" do
        patch lease_path(lease), params: { lease: { terminated_on: termination_date } }
        expect(lease.reload.terminated_on).to eq(termination_date)
      end

      it "redirects to the lease" do
        patch lease_path(lease), params: { lease: { terminated_on: termination_date } }
        expect(response).to redirect_to(lease_path(lease))
      end
    end

    context "when updating quantity" do
      it "updates the quantity" do
        patch lease_path(lease), params: { lease: { quantity: 2 } }
        expect(lease.reload.quantity).to eq(2)
      end
    end

    context "when updating payment_due_in" do
      it "saves the new payment_due_in duration" do
        patch lease_path(lease), params: { lease: { payment_due_in: "P1M9D" } }
        expect(lease.reload.payment_due_in).to eq(1.month + 9.days)
      end

      it "accepts payment_due_in of 0" do
        patch lease_path(lease), params: { lease: { payment_due_in: "P0D" } }
        expect(lease.reload.payment_due_in).to eq(0.days)
      end
    end

    context "when archiving a terminated lease" do
      let(:terminated_lease) do
        create(:lease, start_date: 6.months.ago.to_date, duration_months: 12,
                       terminated_on: 3.months.ago.to_date)
      end
      let(:archive_date) { 2.months.ago.to_date }

      it "sets archived_at on the lease" do
        patch lease_path(terminated_lease), params: { lease: { archived_at: archive_date } }
        expect(terminated_lease.reload.archived_at.to_date).to eq(archive_date)
      end

      it "redirects to the lease" do
        patch lease_path(terminated_lease), params: { lease: { archived_at: archive_date } }
        expect(response).to redirect_to(lease_path(terminated_lease))
      end
    end

    context "when unarchiving a lease" do
      let(:archived_lease) do
        create(:lease, start_date: 6.months.ago.to_date, duration_months: 12,
                       terminated_on: 3.months.ago.to_date, archived_at: 2.months.ago)
      end

      it "clears archived_at" do
        patch lease_path(archived_lease), params: { lease: { archived_at: "" } }
        expect(archived_lease.reload.archived_at).to be_nil
      end
    end
  end

  context "when signed in as an owner" do
    let(:owner) { create(:owner) }
    let!(:owned_property) { create(:property, owner: owner) }

    let(:normal_user) { create(:user) }

    before do
      sign_in_as(normal_user)
      create(:user_association, user: normal_user, associable: owner)
    end

    describe "GET /leases/new" do
      it "returns http success" do
        get new_lease_path
        expect(response).to have_http_status(:success)
      end
    end

    describe "POST /leases" do
      let(:tenant) { create(:tenant) }
      let(:valid_lease_params) do
        {
          property_id: owned_property.id,
          tenant_id: tenant.id,
          start_date: "2025-01-01",
          duration_months: 12,
          rent_amount: 1000,
          security_deposit_value: 2,
          enhancement_period_months: 12,
          enhancement_amount: "5.0",
          enhancement_type: "percentage"
        }
      end

      it "creates a lease on an owned property" do
        expect do
          post leases_path, params: { lease: valid_lease_params }
        end.to change(Lease, :count).by(1)
      end

      it "is forbidden for a property not owned by the user" do
        other_property = create(:property)
        post leases_path, params: { lease: { property_id: other_property.id } }
        expect(response).to have_http_status(:forbidden).or redirect_to(root_path)
      end
    end
  end

  describe "renewal flow" do
    let!(:old_lease) do
      create(:lease, start_date: 1.year.ago.to_date, duration_months: 12, rent_amount: 1000,
                     enhancement_period_months: 12, enhancement_amount: 5, enhancement_type: :percentage)
    end
    let(:renewal_attributes) do
      { property_id: old_lease.property.id, tenant_id: old_lease.tenant.id, start_date: old_lease.end_date + 1.day,
        duration_months: 12, rent_amount: 1050.0, security_deposit_value: 2, enhancement_period_months: 12,
        enhancement_amount: 5, enhancement_type: "percentage", renewed_from_id: old_lease.id }
    end

    it "creates a new lease" do
      expect { post leases_path, params: { lease: renewal_attributes } }.to change(Lease, :count).by(1)
    end

    it "links the new lease to the old one" do
      post leases_path, params: { lease: renewal_attributes }
      expect(Lease.last.renewed_from).to eq(old_lease)
    end

    it "terminates the old lease" do
      post leases_path, params: { lease: renewal_attributes }
      expect(old_lease.reload.terminated_on).to eq(Lease.last.start_date - 1.day)
    end
  end

  describe "JSON via API token" do
    it_behaves_like "serves JSON with a valid API token" do
      let(:json_path) { leases_path(format: :json) }
    end

    it_behaves_like "serves JSON with a valid API token" do
      let(:json_path) { lease_path(create(:lease), format: :json) }
    end
  end
end
