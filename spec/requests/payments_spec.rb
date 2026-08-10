# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Payments" do
  let(:lease) { create(:lease) }

  describe "GET /payments" do
    before { sign_in_admin }

    it "returns http success" do
      get payments_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /payments/new" do
    before { sign_in_admin }

    it "returns http success" do
      get new_payment_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /payments/new lease dropdown filtering" do
    before do
      sign_in_admin
      create(:lease, tenant: active_tenant,
                     start_date: 3.months.ago.to_date, duration_months: 24,
                     cached_balance: 0)
      create(:lease, tenant: balance_tenant,
                     start_date: 3.years.ago.to_date, duration_months: 6,
                     cached_balance: 500)
      create(:lease, tenant: excluded_tenant,
                     start_date: 3.years.ago.to_date, duration_months: 6,
                     cached_balance: 0)
    end

    let(:active_tenant) { create(:tenant, name: "Active Tenant") }
    let(:balance_tenant) { create(:tenant, name: "Balance Tenant") }
    let(:excluded_tenant) { create(:tenant, name: "Excluded Tenant") }

    it "includes active leases with zero balance" do
      get new_payment_path
      expect(response.body).to include("Active Tenant")
    end

    it "includes inactive leases with outstanding balance" do
      get new_payment_path
      expect(response.body).to include("Balance Tenant")
    end

    it "excludes inactive leases with no balance" do
      get new_payment_path
      expect(response.body).not_to include("Excluded Tenant")
    end
  end

  describe "GET /payments/new with lease pre-populated" do
    before { sign_in_admin }

    it "returns success with readonly lease field", :aggregate_failures do
      get new_payment_path(payment: { lease_id: lease.id })
      expect(response).to have_http_status(:success)
      expect(response.body).to include(CGI.escapeHTML(lease.tenant.name))
    end
  end

  describe "GET /payments/new (refund)" do
    before { sign_in_admin }

    it "returns success with refund title", :aggregate_failures do
      get new_payment_path(payment: { payment_type: "refund" })
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Record Refund")
    end
  end

  describe "POST /payments" do
    let(:valid_params) do
      {
        payment: {
          lease_id: lease.id,
          amount: "100.00",
          date: Time.zone.today
        }
      }
    end

    context "with payment_type refund" do
      before { sign_in_admin }

      let(:refund_params) do
        {
          payment: {
            lease_id: lease.id,
            amount: "100.00",
            date: Time.zone.today,
            payment_type: "refund"
          }
        }
      end

      it "creates a refund with positive balance (debit)", :aggregate_failures do
        post payments_path, params: refund_params
        payment = Payment.last
        expect(payment).to be_refund
        expect(payment.balance).to eq(100)
      end
    end

    context "when admin creates payment" do
      before { sign_in_admin }

      it "creates a payment and allocates it" do
        post payments_path, params: valid_params
        expect(Payment.last).to be_partially_allocated
      end

      it "creates initial entry and balance", :aggregate_failures do
        post payments_path, params: valid_params
        payment = Payment.last
        expect(payment.entries.count).to eq(1)
        expect(payment.balance).to eq(-100)
      end

      it "redirects to the payments list" do
        post payments_path, params: valid_params
        expect(response).to redirect_to(payments_path)
      end
    end

    context "when owner creates payment" do
      let(:user) { create(:user) }

      before do
        create(:user_association, user: user, associable: lease.property.owner)
        sign_in_as(user)
      end

      it "creates a payment and allocates it" do
        post payments_path, params: valid_params
        expect(Payment.last).to be_partially_allocated
      end

      it "creates initial entry and balance", :aggregate_failures do
        post payments_path, params: valid_params
        payment = Payment.last
        expect(payment.entries.count).to eq(1)
        expect(payment.balance).to eq(-100)
      end
    end

    context "when tenant creates payment" do
      let(:user) { create(:user) }

      before do
        create(:user_association, user: user, associable: lease.tenant)
        sign_in_as(user)
      end

      it "creates a draft payment" do
        post payments_path, params: valid_params
        expect(Payment.last).to be_draft
      end

      it "does not create initial entry or balance", :aggregate_failures do
        post payments_path, params: valid_params
        payment = Payment.last
        expect(payment.entries.count).to eq(0)
        expect(payment.balance).to eq(0)
      end

      it "redirects to the payments list" do
        post payments_path, params: valid_params
        expect(response).to redirect_to(payments_path)
      end
    end

    context "with invalid parameters" do
      before { sign_in_admin }

      let(:invalid_params) do
        {
          payment: {
            lease_id: lease.id,
            amount: "", # invalid
            date: Time.zone.today
          }
        }
      end

      it "does not create a new Payment" do
        expect do
          post payments_path, params: invalid_params
        end.not_to change(Payment, :count)
      end

      it "renders a response with 422 status" do
        post payments_path, params: invalid_params
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "with attachment" do
      before { sign_in_admin }

      let(:params_with_attachment) do
        {
          payment: {
            lease_id: lease.id,
            amount: "100.00",
            date: Time.zone.today,
            attachment: fixture_file_upload("spec/fixtures/files/sample.png", "image/png")
          }
        }
      end

      it "attaches the file" do
        post payments_path, params: params_with_attachment
        expect(Payment.last.attachment).to be_attached
      end
    end
  end

  describe "GET /payments/:id (refund)" do
    before { sign_in_admin }

    it "shows Refund in the page" do
      refund = create(:payment, :refund, lease: lease)
      get payment_path(refund)
      expect(response.body).to include("Refund")
    end
  end

  describe "PATCH /payments/:id" do
    let(:draft_payment) { create(:payment, lease: lease, status: :draft) }
    let(:confirm_params) { { payment: { status: :confirmed } } }

    context "when owner updates status to confirmed" do
      let(:user) { create(:user) }

      before do
        create(:user_association, user: user, associable: lease.property.owner)
        sign_in_as(user)
      end

      it "confirms and allocates the payment" do
        patch payment_path(draft_payment), params: confirm_params
        expect(draft_payment.reload).to be_partially_allocated
      end

      it "creates initial entry and balance", :aggregate_failures do
        patch payment_path(draft_payment), params: confirm_params
        draft_payment.reload
        expect(draft_payment.entries.count).to eq(1)
        expect(draft_payment.balance).not_to eq(0)
      end

      it "redirects to payment show page" do
        patch payment_path(draft_payment), params: confirm_params
        expect(response).to redirect_to(payment_path(draft_payment))
      end
    end

    context "when tenant tries to update" do
      let(:user) { create(:user) }

      before do
        create(:user_association, user: user, associable: lease.tenant)
        sign_in_as(user)
      end

      it "denies access and redirects" do
        patch payment_path(draft_payment), params: confirm_params
        expect(response).to redirect_to(root_path)
      end

      it "does not confirm the payment" do
        patch payment_path(draft_payment), params: confirm_params
        expect(draft_payment.reload).to be_draft
      end
    end

    context "when admin updates status" do
      before { sign_in_admin }

      it "confirms and allocates the payment" do
        patch payment_path(draft_payment), params: confirm_params
        expect(draft_payment.reload).to be_partially_allocated
      end
    end

    context "when rejecting an allocated payment (the API corruption path)" do
      let!(:invoice) do
        inv = create(:invoice, lease: lease, status: :draft)
        create(:line_item, invoice: inv, amount: 1000, tax_rate: nil)
        inv.update!(status: :finalized)
        inv.reload
      end

      let!(:payment) { create(:payment, lease: lease, amount: 1000, status: :confirmed) }

      before do
        sign_in_admin
        patch payment_path(payment, format: :json), params: { payment: { status: :rejected } }
      end

      it "de-allocates the payment over the JSON API", :aggregate_failures do
        payment.reload
        expect(payment).to be_rejected
        expect(payment.entries).to be_empty
        expect(invoice.reload.balance).to eq(1000)
        expect(lease.reload.cached_balance).to eq(1000)
      end
    end
  end

  describe "GET /payments/:id/edit" do
    before { sign_in_admin }

    let!(:payment) do
      create(:payment, lease: lease, amount: 1000, date: Date.new(2025, 6, 15), status: :confirmed)
    end

    it "renders the correction form", :aggregate_failures do
      get edit_payment_path(payment)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Edit Payment")
    end
  end

  describe "PATCH /payments/:id (correction)" do
    def finalize_invoice(on_lease, amount)
      inv = create(:invoice, lease: on_lease, status: :draft)
      create(:line_item, invoice: inv, amount: amount, tax_rate: nil)
      inv.update!(status: :finalized)
      inv.reload
    end

    context "when re-assigning to another lease over JSON" do
      before { sign_in_admin }

      let(:destination) { create(:lease) }
      let!(:source_invoice) { finalize_invoice(lease, 1000) }
      let!(:dest_invoice) { finalize_invoice(destination, 1000) }
      let!(:payment) do
        create(:payment, lease: lease, amount: 1000, date: Date.new(2025, 6, 15), status: :confirmed)
      end

      it "moves the payment and re-infers both leases", :aggregate_failures do
        patch payment_path(payment, format: :json), params: { payment: { lease_id: destination.id } }

        expect(response).to have_http_status(:ok)
        expect(payment.reload.lease).to eq(destination)
        expect(source_invoice.reload.balance).to eq(1000)
        expect(dest_invoice.reload.balance).to eq(0)
      end

      it "returns a machine-readable cross-tenant warning, still 200", :aggregate_failures do
        patch payment_path(payment, format: :json), params: { payment: { lease_id: destination.id } }

        expect(response).to have_http_status(:ok)
        warnings = response.parsed_body["warnings"]
        expect(warnings).to be_an(Array)
        expect(warnings.pluck("code")).to include("different_tenant")
      end

      # Audit trail: a correcting move must leave a payment Version naming both the
      # source and destination lease. update! (not update_column) is what records
      # it, so this goes red if the move ever skips PaperTrail.
      it "records the source and destination lease in the audit trail", :aggregate_failures do
        patch payment_path(payment, format: :json), params: { payment: { lease_id: destination.id } }

        version = PaperTrail::Version.where(item_type: "Payment", item_id: payment.id, event: "update").last
        expect(version).to be_present
        changes = JSON.parse(version.object_changes)
        expect(changes["lease_id"]).to eq([lease.id, destination.id])
      end
    end

    context "when editing the amount over JSON" do
      before { sign_in_admin }

      let!(:invoice) { finalize_invoice(lease, 1000) }
      let!(:payment) do
        create(:payment, lease: lease, amount: 1000, date: Date.new(2025, 6, 15), status: :confirmed)
      end

      it "re-infers allocations on the payment's lease", :aggregate_failures do
        patch payment_path(payment, format: :json), params: { payment: { amount: 500 } }

        expect(response).to have_http_status(:ok)
        expect(payment.reload.amount).to eq(500)
        expect(invoice.reload.balance).to eq(500)
      end
    end

    context "with a payload mixing status and an editable field" do
      before { sign_in_admin }

      let!(:payment) do
        create(:payment, lease: lease, amount: 1000, date: Date.new(2025, 6, 15), status: :confirmed)
      end

      it "refuses it with 422 and changes nothing", :aggregate_failures do
        patch payment_path(payment, format: :json), params: { payment: { status: :rejected, amount: 500 } }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["errors"]).to have_key("base")
        expect(payment.reload).not_to be_rejected
        expect(payment.amount).to eq(1000)
      end
    end

    context "when correcting a draft" do
      before { sign_in_admin }

      let(:draft) { create(:payment, lease: lease, amount: 1000, date: Date.new(2025, 6, 15), status: :draft) }

      it "does not escalate it to confirmed", :aggregate_failures do
        patch payment_path(draft, format: :json), params: { payment: { amount: 500 } }
        expect(draft.reload).to be_draft
        expect(draft.amount).to eq(500)
      end
    end

    context "when a tenant attempts a correction" do
      let(:user) { create(:user) }
      let!(:payment) do
        create(:payment, lease: lease, amount: 1000, date: Date.new(2025, 6, 15), status: :confirmed)
      end

      before do
        create(:user_association, user: user, associable: lease.tenant)
        sign_in_as(user)
      end

      it "is denied and changes nothing", :aggregate_failures do
        patch payment_path(payment), params: { payment: { amount: 500 } }

        expect(response).to redirect_to(root_path)
        expect(payment.reload.amount).to eq(1000)
      end
    end

    context "when an owner moves onto a lease they cannot see" do
      let(:user) { create(:user) }
      let(:foreign_lease) { create(:lease) }
      let!(:payment) do
        create(:payment, lease: lease, amount: 1000, date: Date.new(2025, 6, 15), status: :confirmed)
      end

      before do
        create(:user_association, user: user, associable: lease.property.owner)
        sign_in_as(user)
      end

      it "is denied by the destination policy and does not move", :aggregate_failures do
        patch payment_path(payment), params: { payment: { lease_id: foreign_lease.id } }

        expect(response).to redirect_to(root_path)
        expect(payment.reload.lease).to eq(lease)
      end
    end
  end

  describe "JSON via API token" do
    it_behaves_like "serves JSON with a valid API token" do
      let(:json_path) { payments_path(format: :json) }
    end

    it_behaves_like "serves JSON with a valid API token" do
      let(:json_path) { payment_path(create(:payment), format: :json) }
    end
  end
end
