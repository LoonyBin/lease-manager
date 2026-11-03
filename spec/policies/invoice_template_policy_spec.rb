# frozen_string_literal: true

require "rails_helper"

RSpec.describe InvoiceTemplatePolicy do
  subject { described_class.new(user, invoice_template) }

  let(:user) { create(:user) }
  let(:lease) { create(:lease) }
  let(:invoice_template) { lease.invoice_templates.first }

  context "when user is an admin" do
    let(:user) { create(:user, :admin) }

    it { is_expected.to permit_actions(%i[create new update edit destroy]) }
  end

  context "when user is associated with the lease's property owner" do
    before do
      create(:user_association, user: user, associable: lease.property.owner)
    end

    it { is_expected.to permit_actions(%i[create new update edit destroy]) }
  end

  context "when user is associated with the lease's tenant" do
    before do
      create(:user_association, user: user, associable: lease.tenant)
    end

    it { is_expected.to forbid_actions(%i[create new update edit destroy]) }
  end

  context "when user is unrelated" do
    it { is_expected.to forbid_actions(%i[create new update edit destroy]) }
  end
end
