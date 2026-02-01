# frozen_string_literal: true

require "rails_helper"

RSpec.describe InvoicePolicy do
  subject { described_class.new(user, invoice) }

  let(:user) { create(:user) }
  let(:lease) { create(:lease) }
  let(:invoice) { create(:invoice, lease: lease) }

  context "when user is an admin" do
    let(:user) { create(:user, :admin) }

    it { is_expected.to permit_actions(%i[index show create new update edit destroy]) }
  end

  context "when user is associated with the lease's property owner" do
    before do
      create(:user_association, user: user, associable: lease.property.owner)
    end

    it { is_expected.to permit_actions(%i[index show create new update edit destroy]) }
  end

  context "when user is associated with the lease's tenant" do
    before do
      create(:user_association, user: user, associable: lease.tenant)
    end

    it { is_expected.to permit_actions(%i[index show]) }
    it { is_expected.to forbid_actions(%i[create new update edit destroy]) }
  end

  context "when user is unrelated" do
    it { is_expected.to forbid_actions(%i[show create new update edit destroy]) }
  end

  describe "Scope" do
    subject(:scope) { described_class::Scope.new(user, Invoice).resolve }

    let(:user) { create(:user) }

    context "when user is admin" do
      let(:user) { create(:user, :admin) }

      it "includes all invoices" do
        invoices = create_list(:invoice, 3)
        expect(scope).to include(*invoices)
      end
    end

    context "when user is associated with property owner" do
      let!(:owned_invoice) { create(:invoice) }
      let!(:unrelated_invoice) { create(:invoice) }

      before { create(:user_association, user: user, associable: owned_invoice.lease.property.owner) }

      it "includes owned invoice" do
        expect(scope).to include(owned_invoice)
      end

      it "excludes unrelated invoices" do
        expect(scope).not_to include(unrelated_invoice)
      end
    end

    context "when user is associated with tenant" do
      let!(:tenant_invoice) { create(:invoice) }
      let!(:unrelated_invoice) { create(:invoice) }

      before { create(:user_association, user: user, associable: tenant_invoice.lease.tenant) }

      it "includes tenant invoice" do
        expect(scope).to include(tenant_invoice)
      end

      it "excludes unrelated invoices" do
        expect(scope).not_to include(unrelated_invoice)
      end
    end
  end
end
