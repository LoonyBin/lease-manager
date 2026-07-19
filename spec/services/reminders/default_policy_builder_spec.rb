# frozen_string_literal: true

require "rails_helper"

RSpec.describe Reminders::DefaultPolicyBuilder do
  subject(:builder) { described_class.new(lease) }

  let(:tenant) { create(:tenant, email: "Tenant@Example.com") }
  let(:lease) { create(:lease, tenant: tenant) }

  before { lease.reminder_steps.destroy_all }

  def unknown_placeholders_in(step)
    InvoiceTemplates::TextRenderer.unknown_placeholders("#{step.subject} #{step.body}",
                                                        Reminders::Context::VARIABLE_NAMES)
  end

  describe "#call" do
    it "builds the near-due, due and repeating overdue ladder", :aggregate_failures do
      steps = builder.call

      expect(steps.map(&:offset_days)).to eq([-7, 0, 7])
      expect(steps.map(&:position)).to eq([1, 2, 3])
      expect(steps.map(&:repeat_every_days)).to eq([nil, nil, 14])
    end

    it "seeds recipients from the tenant's address, normalised" do
      expect(builder.call.map(&:to_emails).uniq).to eq([["tenant@example.com"]])
    end

    it "includes the emails of users associated with the tenant" do
      user = create(:user, email: "agent@example.com")
      create(:user_association, user: user, associable: tenant)

      expect(builder.call.first.to_emails).to contain_exactly("tenant@example.com", "agent@example.com")
    end

    it "builds valid steps" do
      expect(builder.call).to all(be_valid)
    end

    it "uses only known placeholders" do
      unknown = builder.call.flat_map { |step| unknown_placeholders_in(step) }
      expect(unknown).to be_empty
    end

    context "when no recipient address is known" do
      let(:tenant) { create(:tenant, email: nil) }

      it "builds nothing rather than an invalid policy" do
        expect(builder.call).to be_empty
      end
    end
  end
end
