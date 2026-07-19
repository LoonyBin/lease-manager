# frozen_string_literal: true

require "rails_helper"

RSpec.describe InvoiceNotificationPolicy do
  subject { described_class.new(user, notification) }

  let(:user) { create(:user) }
  let(:lease) { create(:lease) }
  let(:notification) { create(:invoice_notification, invoice: create(:invoice, lease: lease)) }

  context "when user is an admin" do
    let(:user) { create(:user, :admin) }

    it { is_expected.to permit_actions(%i[index show approve cancel retry approve_all]) }
  end

  # Approving a send is outward-facing, so even the property owner does not
  # get the outbox — only admins do.
  context "when user is associated with the lease's property owner" do
    before { create(:user_association, user: user, associable: lease.property.owner) }

    it { is_expected.to forbid_actions(%i[index show approve cancel retry approve_all]) }
  end

  context "when user is unrelated" do
    it { is_expected.to forbid_actions(%i[index show approve cancel retry approve_all]) }
  end

  describe "Scope" do
    it "resolves every notification for an admin" do
      admin = create(:user, :admin)
      expect(described_class::Scope.new(admin, InvoiceNotification).resolve).to include(notification)
    end

    it "resolves nothing for a non-admin" do
      create(:user_association, user: user, associable: lease.property.owner)
      expect(described_class::Scope.new(user, InvoiceNotification).resolve).to be_empty
    end
  end
end
