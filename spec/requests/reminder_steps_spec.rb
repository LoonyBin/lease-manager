# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ReminderSteps" do
  before { sign_in_admin }

  let(:lease) { create(:lease) }
  let(:step) { lease.reminder_steps.first }

  let(:valid_params) do
    { reminder_step: { position: 4, offset_days: 21, repeat_every_days: 7,
                       subject: "Final notice for invoice {invoice_number}",
                       body: "{tenant_name}, {balance_due} remains outstanding after {days_overdue} days.",
                       to_emails: "collections@example.com, legal@example.com" } }
  end

  describe "GET /leases/:lease_id/reminder_steps/new" do
    it "returns http success" do
      get new_lease_reminder_step_path(lease)
      expect(response).to have_http_status(:success)
    end

    it "suggests the tenant's and owner's addresses without constraining them", :aggregate_failures do
      owner_user = create(:user, email: "owner.agent@example.com")
      create(:user_association, user: owner_user, associable: lease.property.owner)

      get new_lease_reminder_step_path(lease)
      expect(response.body).to include(lease.tenant.email)
      expect(response.body).to include("owner.agent@example.com")
    end
  end

  describe "POST /leases/:lease_id/reminder_steps" do
    it "creates a step and redirects to the lease", :aggregate_failures do
      expect { post lease_reminder_steps_path(lease), params: valid_params }
        .to change(lease.reminder_steps, :count).by(1)
      expect(response).to redirect_to(lease_path(lease))
    end

    it "saves free-text addresses that belong to no user account" do
      post lease_reminder_steps_path(lease), params: valid_params
      expect(lease.reminder_steps.last.to_emails)
        .to eq(%w[collections@example.com legal@example.com])
    end

    context "with an unknown placeholder" do
      it "rejects the step", :aggregate_failures do
        params = valid_params.deep_merge(reminder_step: { subject: "Notice {invoice_nmbr}" })
        expect { post lease_reminder_steps_path(lease), params: params }
          .not_to change(lease.reminder_steps, :count)
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("references unknown placeholders: invoice_nmbr")
      end
    end

    context "with no recipients" do
      it "rejects the step", :aggregate_failures do
        params = valid_params.deep_merge(reminder_step: { to_emails: "" })
        expect { post lease_reminder_steps_path(lease), params: params }
          .not_to change(lease.reminder_steps, :count)
        expect(response.body).to include("must include at least one email address")
      end
    end
  end

  describe "GET /leases/:lease_id/reminder_steps/:id/edit" do
    it "returns http success" do
      get edit_lease_reminder_step_path(lease, step)
      expect(response).to have_http_status(:success)
    end
  end

  describe "PATCH /leases/:lease_id/reminder_steps/:id" do
    it "updates the step", :aggregate_failures do
      patch lease_reminder_step_path(lease, step), params: { reminder_step: { offset_days: -3 } }
      expect(response).to redirect_to(lease_path(lease))
      expect(step.reload.offset_days).to eq(-3)
    end

    it "escalates the recipients" do
      patch lease_reminder_step_path(lease, step),
            params: { reminder_step: { to_emails: "Escalation@Example.com" } }
      expect(step.reload.to_emails).to eq(["escalation@example.com"])
    end
  end

  describe "DELETE /leases/:lease_id/reminder_steps/:id" do
    it "deletes the step", :aggregate_failures do
      step_to_delete = step
      expect { delete lease_reminder_step_path(lease, step_to_delete) }
        .to change(lease.reminder_steps, :count).by(-1)
      expect(response).to redirect_to(lease_path(lease))
    end

    it "keeps already-queued notifications as audit history" do
      notification = create(:invoice_notification, reminder_step: step,
                                                   invoice: create(:invoice, lease: lease))
      delete lease_reminder_step_path(lease, step)
      expect(notification.reload.reminder_step_id).to be_nil
    end
  end

  describe "authorization" do
    it "denies a user unrelated to the lease" do
      sign_in_user
      get new_lease_reminder_step_path(lease)
      expect(response).to redirect_to(root_path)
    end
  end
end
