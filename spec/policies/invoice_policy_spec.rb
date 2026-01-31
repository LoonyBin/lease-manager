# frozen_string_literal: true

require "rails_helper"
require "pundit/rspec"

RSpec.describe InvoicePolicy, type: :policy do
  subject { described_class }

  let(:user) { create(:user) }
  let(:lease) { create(:lease) }
  let(:invoice) { create(:invoice, lease: lease) }

  context "when user is an admin" do
    let(:user) { create(:user, :admin) }

    permissions :index?, :show?, :create?, :new?, :update?, :edit?, :destroy? do
      it "grants access" do
        is_expected.to permit(user, invoice)
      end
    end
  end

  context "when user is associated with the lease's property owner" do
    before do
      create(:user_association, user: user, associable: lease.property.owner)
    end

    permissions :index?, :show?, :create?, :new?, :update?, :edit?, :destroy? do
      it "grants access" do
        is_expected.to permit(user, invoice)
      end
    end
  end

  context "when user is associated with the lease's tenant" do
    before do
      create(:user_association, user: user, associable: lease.tenant)
    end

    permissions :index?, :show? do
      it "grants access" do
        is_expected.to permit(user, invoice)
      end
    end

    permissions :create?, :new?, :update?, :edit?, :destroy? do
      it "denies access" do
        is_expected.not_to permit(user, invoice)
      end
    end
  end

  context "when user is unrelated" do
    permissions :show?, :create?, :new?, :update?, :edit?, :destroy? do
      it "denies access" do
        is_expected.not_to permit(user, invoice)
      end
    end
  end

  describe "Scope" do
    let(:user) { create(:user) }

    def resolve_scope
      described_class::Scope.new(user, Invoice).resolve
    end

    context "when user is admin" do
      let(:user) { create(:user, :admin) }

      it "includes all invoices" do
        invoices = create_list(:invoice, 3)
        expect(resolve_scope).to include(*invoices)
      end
    end

    context "when user is associated with property owner" do
      let!(:owned_invoice) { create(:invoice) }
      let!(:unrelated_invoice) { create(:invoice) }

      before { create(:user_association, user: user, associable: owned_invoice.lease.property.owner) }

      it "includes owned invoice" do
        expect(resolve_scope).to include(owned_invoice)
      end

      it "excludes unrelated invoices" do
        expect(resolve_scope).not_to include(unrelated_invoice)
      end
    end

    context "when user is associated with tenant" do
      let!(:tenant_invoice) { create(:invoice) }
      let!(:unrelated_invoice) { create(:invoice) }

      before { create(:user_association, user: user, associable: tenant_invoice.lease.tenant) }

      it "includes tenant invoice" do
        expect(resolve_scope).to include(tenant_invoice)
      end

      it "excludes unrelated invoices" do
        expect(resolve_scope).not_to include(unrelated_invoice)
      end
    end
  end
end
