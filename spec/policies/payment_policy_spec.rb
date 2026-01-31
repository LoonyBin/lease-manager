# frozen_string_literal: true

require "rails_helper"
require "pundit/rspec"

RSpec.describe PaymentPolicy, type: :policy do
  subject { described_class }

  let(:user) { create(:user) }
  let(:lease) { create(:lease) }
  let(:payment) { create(:payment, lease: lease) }

  context "when user is an admin" do
    let(:user) { create(:user, :admin) }

    permissions :index?, :show?, :create?, :new?, :update?, :edit?, :destroy? do
      it "grants access" do
        is_expected.to permit(user, payment)
      end
    end
  end

  context "when user is associated with the lease's property owner" do
    before do
      create(:user_association, user: user, associable: lease.property.owner)
    end

    permissions :index?, :show?, :create?, :new?, :update?, :edit?, :destroy? do
      it "grants access" do
        is_expected.to permit(user, payment)
      end
    end
  end

  context "when user is associated with the lease's tenant" do
    before do
      create(:user_association, user: user, associable: lease.tenant)
    end

    permissions :index?, :show? do
      it "grants access" do
        is_expected.to permit(user, payment)
      end
    end

    permissions :create?, :new?, :update?, :edit?, :destroy? do
      it "denies access" do
        is_expected.not_to permit(user, payment)
      end
    end
  end

  context "when user is unrelated" do
    permissions :show?, :create?, :new?, :update?, :edit?, :destroy? do
      it "denies access" do
        is_expected.not_to permit(user, payment)
      end
    end
  end

  describe "Scope" do
    let(:user) { create(:user) }

    def resolve_scope
      described_class::Scope.new(user, Payment).resolve
    end

    context "when user is admin" do
      let(:user) { create(:user, :admin) }

      it "includes all payments" do
        payments = create_list(:payment, 3)
        expect(resolve_scope).to include(*payments)
      end
    end

    context "when user is associated with property owner" do
      let!(:owned_payment) { create(:payment) }
      let!(:unrelated_payment) { create(:payment) }

      before { create(:user_association, user: user, associable: owned_payment.lease.property.owner) }

      it "includes owned payment" do
        expect(resolve_scope).to include(owned_payment)
      end

      it "excludes unrelated payments" do
        expect(resolve_scope).not_to include(unrelated_payment)
      end
    end

    context "when user is associated with tenant" do
      let!(:tenant_payment) { create(:payment) }
      let!(:unrelated_payment) { create(:payment) }

      before { create(:user_association, user: user, associable: tenant_payment.lease.tenant) }

      it "includes tenant payment" do
        expect(resolve_scope).to include(tenant_payment)
      end

      it "excludes unrelated payments" do
        expect(resolve_scope).not_to include(unrelated_payment)
      end
    end
  end
end
