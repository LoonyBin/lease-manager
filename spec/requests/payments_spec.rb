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

    context "when admin creates payment" do
      before { sign_in_admin }

      it "creates a confirmed payment" do
        post payments_path, params: valid_params
        expect(Payment.last).to be_confirmed
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

      it "creates a confirmed payment" do
        post payments_path, params: valid_params
        expect(Payment.last).to be_confirmed
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

  describe "PATCH /payments/:id" do
    let(:draft_payment) { create(:payment, lease: lease, status: :draft) }
    let(:confirm_params) { { payment: { status: :confirmed } } }

    context "when owner updates status to confirmed" do
      let(:user) { create(:user) }

      before do
        create(:user_association, user: user, associable: lease.property.owner)
        sign_in_as(user)
      end

      it "confirms the payment" do
        patch payment_path(draft_payment), params: confirm_params
        expect(draft_payment.reload).to be_confirmed
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

      it "confirms the payment" do
        patch payment_path(draft_payment), params: confirm_params
        expect(draft_payment.reload).to be_confirmed
      end
    end
  end
end
