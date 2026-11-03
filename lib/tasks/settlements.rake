# frozen_string_literal: true

namespace :settlements do
  desc "Re-adjust settlements for a lease (oldest to newest). Usage: rake settlements:readjust LEASE_ID=<id>"
  task readjust: :environment do
    lease_id = ENV.fetch("LEASE_ID", nil)
    abort "LEASE_ID is required. Usage: rake settlements:readjust LEASE_ID=<id>" if lease_id.blank?

    lease = Lease.find_by(id: lease_id)
    abort "Lease #{lease_id} not found" unless lease

    result = SettlementService.readjust(lease)

    puts "Readjusted settlements for Lease ##{lease.id} (#{lease})"
    puts "  Cleared #{result[:settlement_count]} settlement entries"
    puts "  Removed #{result[:orphan_count]} orphaned initial entries from rejected payments"
    puts "  Re-settled #{result[:credit_count]} credits"
    puts "  Balance: #{result[:old_balance]} -> #{result[:new_balance]}"
  end
end
