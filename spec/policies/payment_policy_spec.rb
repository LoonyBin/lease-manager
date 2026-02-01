# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentPolicy do
  subject { described_class.new(user, payment) }

  let(:user) { create(:user) }
  let(:lease) { create(:lease) }
  let(:payment) { create(:payment, lease: lease) }

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
    subject(:scope) { described_class::Scope.new(user, Payment).resolve }

    let(:user) { create(:user) }

    context "when user is admin" do
      let(:user) { create(:user, :admin) }

      it "includes all payments" do
        payments = create_list(:payment, 3)
        expect(scope).to include(*payments)
      end
    end

    context "when user is associated with property owner" do
      let!(:owned_payment) { create(:payment) }
      let!(:unrelated_payment) { create(:payment) }

      before { create(:user_association, user: user, associable: owned_payment.lease.property.owner) }

      it "includes owned payment" do
        expect(scope).to include(owned_payment)
      end

      it "excludes unrelated payments" do
        expect(scope).not_to include(unrelated_payment)
      end
    end

    context "when user is associated with tenant" do
      let!(:tenant_payment) { create(:payment) }
      let!(:unrelated_payment) { create(:payment) }

      before { create(:user_association, user: user, associable: tenant_payment.lease.tenant) }

      it "includes tenant payment" do
        expect(scope).to include(tenant_payment)
      end

      it "excludes unrelated payments" do
        expect(scope).not_to include(unrelated_payment)
      end
    end
  end
end
