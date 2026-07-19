# frozen_string_literal: true

namespace :reminders do
  desc "Queue reminder notifications for invoices due against each lease's policy"
  task schedule: :environment do
    ScheduleInvoiceRemindersJob.perform_later
    puts "Enqueued ScheduleInvoiceRemindersJob"
  end

  desc "Create the default reminder policy for leases that have none (idempotent)"
  task backfill_default_steps: :environment do
    created = 0
    skipped = 0

    Lease.not_archived.where.missing(:reminder_steps).find_each do |lease|
      steps = Reminders::DefaultPolicyBuilder.new(lease).call
      if steps.empty?
        skipped += 1
        puts "Lease #{lease.id} (#{lease}) has no known recipient address; skipped"
        next
      end

      # All-or-nothing per lease: a step that fails validation must not leave
      # the lease with a partial policy that then looks already-backfilled.
      Lease.transaction { steps.each(&:save!) }
      created += 1
    rescue ActiveRecord::RecordInvalid => e
      skipped += 1
      puts "Lease #{lease.id} skipped: #{e.message}"
    end

    puts "Backfilled default reminder steps for #{created} lease(s); skipped #{skipped}"
  end
end
