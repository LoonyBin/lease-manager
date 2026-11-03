# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReminderStepPolicy do
  subject { described_class.new(user, reminder_step) }

  let(:user) { create(:user) }
  let(:lease) { create(:lease) }
  let(:reminder_step) { lease.reminder_steps.first || create(:reminder_step, lease: lease) }

  context "when user is an admin" do
    let(:user) { create(:user, :admin) }

    it { is_expected.to permit_actions(%i[create new update edit destroy]) }
  end

  context "when user is associated with the lease's property owner" do
    before { create(:user_association, user: user, associable: lease.property.owner) }

    it { is_expected.to permit_actions(%i[create new update edit destroy]) }
  end

  context "when user is associated with the lease's tenant" do
    before { create(:user_association, user: user, associable: lease.tenant) }

    it { is_expected.to forbid_actions(%i[create new update edit destroy]) }
  end

  context "when user is unrelated" do
    it { is_expected.to forbid_actions(%i[create new update edit destroy]) }
  end

  describe "Scope" do
    it "resolves every step for an admin" do
      admin = create(:user, :admin)
      expect(described_class::Scope.new(admin, ReminderStep).resolve).to include(reminder_step)
    end

    it "resolves steps on the user's own leases" do
      create(:user_association, user: user, associable: lease.property.owner)
      expect(described_class::Scope.new(user, ReminderStep).resolve).to include(reminder_step)
    end

    it "excludes steps on other people's leases" do
      expect(described_class::Scope.new(user, ReminderStep).resolve).not_to include(reminder_step)
    end
  end
end
