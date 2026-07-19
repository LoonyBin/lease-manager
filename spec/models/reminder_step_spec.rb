# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReminderStep do
  subject(:step) { build(:reminder_step) }

  describe "associations" do
    it { is_expected.to belong_to(:lease) }
    it { is_expected.to have_many(:invoice_notifications).dependent(:nullify) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:position) }
    it { is_expected.to validate_presence_of(:offset_days) }
    it { is_expected.to validate_presence_of(:subject) }
    it { is_expected.to validate_presence_of(:body) }

    it "requires at least one recipient" do
      step = build(:reminder_step, to_emails: [])
      step.valid?
      expect(step.errors[:to_emails]).to include("must include at least one email address")
    end

    it "rejects a malformed address" do
      step = build(:reminder_step, to_emails: ["not-an-email"])
      step.valid?
      expect(step.errors[:to_emails]).to include("contains invalid addresses: not-an-email")
    end

    it "rejects a zero repeat interval" do
      expect(build(:reminder_step, repeat_every_days: 0)).not_to be_valid
    end

    it "allows a blank repeat interval" do
      expect(build(:reminder_step, repeat_every_days: nil)).to be_valid
    end

    # The validation is the real guard; the check constraint is what stops a
    # non-advancing repeat sneaking past it via update_column or raw SQL.
    it "rejects a zero repeat interval at the database too" do
      step = create(:reminder_step, repeat_every_days: 7)
      # rubocop:disable Rails/SkipsModelValidations -- skipping them is exactly what is under test
      sneak_past_validations = -> { step.update_column(:repeat_every_days, 0) }
      # rubocop:enable Rails/SkipsModelValidations

      expect(&sneak_past_validations)
        .to raise_error(ActiveRecord::StatementInvalid, /reminder_steps_repeat_every_days_positive/)
    end

    it "rejects an offset beyond a year" do
      expect(build(:reminder_step, offset_days: 400)).not_to be_valid
    end

    it "rejects unknown placeholders in the subject" do
      step = build(:reminder_step, subject: "Invoice {invoice_nmbr} due")
      step.valid?
      expect(step.errors[:subject]).to include("references unknown placeholders: invoice_nmbr")
    end

    it "rejects unknown placeholders in the body" do
      step = build(:reminder_step, body: "Hello {tenant_nmae}")
      step.valid?
      expect(step.errors[:body]).to include("references unknown placeholders: tenant_nmae")
    end

    it "accepts invoice-template placeholders alongside reminder ones" do
      expect(build(:reminder_step, body: "Rent {rent} for {month_name} {year}, due {due_date}")).to be_valid
    end
  end

  describe "#to_emails=" do
    it "splits, strips and downcases a comma-separated string" do
      step = build(:reminder_step, to_emails: " First@Example.com ,second@example.COM ")
      expect(step.to_emails).to eq(%w[first@example.com second@example.com])
    end

    it "splits on semicolons and whitespace" do
      step = build(:reminder_step, to_emails: "a@example.com; b@example.com c@example.com")
      expect(step.to_emails).to eq(%w[a@example.com b@example.com c@example.com])
    end

    it "drops blanks and duplicates" do
      step = build(:reminder_step, to_emails: ["a@example.com", "", "A@example.com", nil])
      expect(step.to_emails).to eq(["a@example.com"])
    end

    it "normalises an array too" do
      step = build(:reminder_step, to_emails: [" Keep@Example.com "])
      expect(step.to_emails).to eq(["keep@example.com"])
    end
  end

  describe "#occurrences_for" do
    let(:due_date) { Date.new(2026, 3, 10) }

    it "returns the single offset date for a non-repeating step" do
      step = build(:reminder_step, offset_days: -7)
      expect(step.occurrences_for(due_date, up_to: due_date)).to eq([Date.new(2026, 3, 3)])
    end

    it "returns nothing before the step comes round" do
      step = build(:reminder_step, offset_days: -7)
      expect(step.occurrences_for(due_date, up_to: Date.new(2026, 3, 1))).to be_empty
    end

    it "enumerates repeats up to the cutoff" do
      step = build(:reminder_step, offset_days: 7, repeat_every_days: 14)
      expect(step.occurrences_for(due_date, up_to: Date.new(2026, 4, 20)))
        .to eq([Date.new(2026, 3, 17), Date.new(2026, 3, 31), Date.new(2026, 4, 14)])
    end

    it "caps runaway enumeration" do
      step = build(:reminder_step, offset_days: 0, repeat_every_days: 1)
      expect(step.occurrences_for(due_date, up_to: due_date + 10.years).size)
        .to eq(described_class::MAX_REPEATS_PER_STEP)
    end
  end

  describe "#latest_occurrence_for" do
    let(:due_date) { Date.new(2026, 3, 10) }

    it "returns only the most recent firing, not the whole backlog" do
      step = build(:reminder_step, offset_days: 7, repeat_every_days: 14)
      expect(step.latest_occurrence_for(due_date, up_to: Date.new(2026, 4, 20))).to eq(Date.new(2026, 4, 14))
    end

    it "returns nil when the step has not come round yet" do
      step = build(:reminder_step, offset_days: 7)
      expect(step.latest_occurrence_for(due_date, up_to: Date.new(2026, 3, 12))).to be_nil
    end

    it "returns the firing on the day it comes round" do
      step = build(:reminder_step, offset_days: 7, repeat_every_days: 14)
      expect(step.latest_occurrence_for(due_date, up_to: Date.new(2026, 3, 17))).to eq(Date.new(2026, 3, 17))
    end

    # Enumerating occurrences stops at MAX_REPEATS_PER_STEP; the latest firing
    # must stay accurate past that cap or a long-overdue step silently stalls
    # on an occurrence it has already sent.
    it "stays accurate beyond the occurrence-enumeration cap" do
      step = build(:reminder_step, offset_days: 7, repeat_every_days: 14)
      repeats = ReminderStep::MAX_REPEATS_PER_STEP + 20
      up_to = due_date + 7 + (repeats * 14)

      expect(step.latest_occurrence_for(due_date, up_to: up_to)).to eq(up_to)
    end
  end

  describe "#to_s" do
    it "describes a step before the due date" do
      expect(build(:reminder_step, offset_days: -7).to_s).to eq("7 days before due")
    end

    it "describes a step on the due date" do
      expect(build(:reminder_step, offset_days: 0).to_s).to eq("On due date")
    end

    it "describes a repeating overdue step" do
      expect(build(:reminder_step, offset_days: 7, repeat_every_days: 14).to_s)
        .to eq("7 days after due, repeating every 14 days")
    end
  end

  describe ".for_reminding_leases" do
    let(:archived_lease) do
      create(:lease, start_date: Date.new(2026, 1, 1))
        .tap { |l| l.update!(terminated_on: Date.new(2026, 6, 30), archived_at: Time.current) }
    end

    it "includes steps on an active, opted-in lease" do
      expect(described_class.for_reminding_leases).to include(create(:reminder_step))
    end

    it "excludes steps on an opted-out lease" do
      step = create(:reminder_step, lease: create(:lease, reminders_enabled: false))
      expect(described_class.for_reminding_leases).not_to include(step)
    end

    it "excludes steps on an archived lease" do
      step = create(:reminder_step, lease: archived_lease)
      expect(described_class.for_reminding_leases).not_to include(step)
    end
  end
end
