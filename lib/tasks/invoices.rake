# frozen_string_literal: true

namespace :invoices do
  desc "Generate monthly invoices for all active leases"
  task generate: :environment do
    GenerateInvoicesJob.perform_later
    puts "Enqueued GenerateInvoicesJob"
  end
end
