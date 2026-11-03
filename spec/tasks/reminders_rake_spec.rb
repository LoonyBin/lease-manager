# frozen_string_literal: true

require "rails_helper"
require "rake"

RSpec.describe "reminders:backfill_default_steps", type: :task do # -- Rake task spec
  before(:all) do # rubocop:disable RSpec/BeforeAfterAll -- Rake tasks only need loading once
    Rails.application.load_tasks
  end

  around do |example|
    example.run
    Rake::Task["reminders:backfill_default_steps"].reenable
  end

  it "creates the default policy for a lease that has none" do
    lease = create(:lease)
    lease.reminder_steps.destroy_all

    expect { Rake::Task["reminders:backfill_default_steps"].invoke }
      .to change { lease.reminder_steps.count }.from(0).to(3)
  end

  it "leaves a lease that already has steps alone" do
    lease = create(:lease)
    lease.reminder_steps.where.not(position: 1).destroy_all

    expect { Rake::Task["reminders:backfill_default_steps"].invoke }
      .not_to(change { lease.reminder_steps.count })
  end

  it "skips a lease with no known recipient address" do
    lease = create(:lease, tenant: create(:tenant, email: nil))
    lease.reminder_steps.destroy_all

    expect { Rake::Task["reminders:backfill_default_steps"].invoke }
      .not_to(change { lease.reminder_steps.count })
  end

  it "skips archived leases" do
    lease = create(:lease, start_date: Date.new(2026, 1, 1))
    lease.reminder_steps.destroy_all
    lease.update!(terminated_on: Date.new(2026, 6, 30), archived_at: Time.current)

    expect { Rake::Task["reminders:backfill_default_steps"].invoke }
      .not_to(change { lease.reminder_steps.count })
  end
end
