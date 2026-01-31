# frozen_string_literal: true

# Load FactoryBot and Faker for seeding
require "factory_bot_rails"
require "faker"

include FactoryBot::Syntax::Methods

puts "Seeding database..."

# Clear existing data in reverse dependency order
puts "Clearing existing data..."
PaymentAllocation.destroy_all
Payment.destroy_all
LineItem.destroy_all
Invoice.destroy_all
Lease.destroy_all
Property.destroy_all
Tenant.destroy_all
Owner.destroy_all
UserAssociation.destroy_all
User.destroy_all

# Create admin user
puts "Creating admin user..."
admin = create(:user, :admin, name: "Admin User", email: "admin@example.com", uid: "admin")
puts "  Created admin: #{admin.email}"

# Create normal user
puts "Creating normal user..."
normal_user = create(:user, name: "Normal User", email: "user@example.com", uid: "user")
puts "  Created user: #{normal_user.email}"

# Create owners
puts "Creating owners..."
owners = 3.times.map do
  create(:owner).tap { |o| puts "  Created owner: #{o.name}" }
end

# Associate normal user with first two owners (so they can see some data)
puts "Associating normal user with owners..."
owners.take(2).each do |owner|
  create(:user_association, user: normal_user, associable: owner)
  puts "  Associated #{normal_user.name} with #{owner.name}"
end

# Create properties for each owner (some will have no leases)
puts "Creating properties..."
properties = owners.flat_map do |owner|
  rand(3..5).times.map do
    create(:property, owner: owner).tap { |p| puts "  Created property: #{p.name} (#{owner.name})" }
  end
end

# Create tenants
puts "Creating tenants..."
tenants = 12.times.map do
  create(:tenant).tap { |t| puts "  Created tenant: #{t.name}" }
end

# Create leases with various scenarios
puts "Creating leases..."
leases = []

# Select properties for leases (leave some without leases)
properties_with_leases = properties.sample(properties.size - 3)

properties_with_leases.each_with_index do |property, index|
  tenant = tenants.sample

  # Create different lease scenarios
  case index % 5
  when 0
    # Regular active lease (full invoice history, leave last 2 months ungenerated)
    start_date = 12.months.ago.beginning_of_month
    lease = create(:lease, :randomized,
                   property: property,
                   tenant: tenant,
                   start_date: start_date,
                   duration_months: 24)
    leases << { lease: lease, generate_until: 2.months.ago.beginning_of_month, type: :active_with_gap }
    puts "  Created active lease (with gap): #{property.name} -> #{tenant.name}"

  when 1
    # Terminated lease
    start_date = 18.months.ago.beginning_of_month
    lease = create(:lease, :randomized,
                   property: property,
                   tenant: tenant,
                   start_date: start_date,
                   duration_months: 24,
                   terminated_on: 3.months.ago.end_of_month)
    leases << { lease: lease, generate_until: lease.end_date, type: :terminated }
    puts "  Created terminated lease: #{property.name} -> #{tenant.name}"

  when 2
    # Recently started lease (only 1-2 months old, leave current month ungenerated)
    start_date = 2.months.ago.beginning_of_month
    lease = create(:lease, :randomized,
                   property: property,
                   tenant: tenant,
                   start_date: start_date,
                   duration_months: 12)
    leases << { lease: lease, generate_until: 1.month.ago.beginning_of_month, type: :new_with_gap }
    puts "  Created new lease (with gap): #{property.name} -> #{tenant.name}"

  when 3
    # Fully invoiced active lease
    start_date = 8.months.ago.beginning_of_month
    lease = create(:lease, :randomized,
                   property: property,
                   tenant: tenant,
                   start_date: start_date,
                   duration_months: 12)
    leases << { lease: lease, generate_until: Date.current.beginning_of_month, type: :fully_invoiced }
    puts "  Created fully invoiced lease: #{property.name} -> #{tenant.name}"

  when 4
    # Lease about to expire (ends this month or next)
    start_date = 11.months.ago.beginning_of_month
    lease = create(:lease, :randomized,
                   property: property,
                   tenant: tenant,
                   start_date: start_date,
                   duration_months: 12)
    leases << { lease: lease, generate_until: Date.current.beginning_of_month, type: :expiring_soon }
    puts "  Created expiring lease: #{property.name} -> #{tenant.name}"
  end
end

# Create a renewed lease scenario
puts "Creating renewed lease..."
old_lease_property = (properties - properties_with_leases).first
if old_lease_property
  old_tenant = tenants.sample
  old_start = 18.months.ago.beginning_of_month
  old_lease = create(:lease, :randomized,
                     property: old_lease_property,
                     tenant: old_tenant,
                     start_date: old_start,
                     duration_months: 12)
  leases << { lease: old_lease, generate_until: old_lease.end_date, type: :expired_for_renewal }
  puts "  Created old lease for renewal: #{old_lease_property.name}"

  # Create the renewal
  new_lease = Lease.build_renewal(old_lease)
  new_lease.save!
  leases << { lease: new_lease, generate_until: 1.month.ago.beginning_of_month, type: :renewal_with_gap }
  puts "  Created renewal lease: #{old_lease_property.name} -> #{old_tenant.name}"
end

puts "  #{properties.size - properties_with_leases.size - 1} properties left without leases"

# Generate invoices for each lease based on its type
puts "Generating invoices..."
leases.each do |lease_data|
  lease = lease_data[:lease]
  generate_until = lease_data[:generate_until]
  lease_type = lease_data[:type]

  current_date = lease.start_date
  end_date = [generate_until, lease.end_date, Date.current].compact.min

  while current_date <= end_date
    invoice = InvoiceGenerator.new(lease, current_date).call
    invoice.save!

    # Finalize older invoices (not current month drafts)
    if current_date < Date.current.beginning_of_month
      invoice.update!(status: :finalized)
      InvoiceNumberingService.new(invoice).call
      invoice.save!
    end

    puts "  Created invoice: #{invoice.number || 'DRAFT'} for #{lease.property.name} (#{current_date.strftime('%B %Y')})"
    current_date = current_date.next_month
  end

  # Report gaps for testing
  missing = lease.missing_invoice_months
  if missing.any?
    puts "    -> #{missing.size} months left ungenerated for testing: #{missing.map { |d| d.strftime('%b %Y') }.join(', ')}"
  end
end

# Mark some invoices as sent or cancelled for variety
puts "Setting varied invoice statuses..."
finalized_invoices = Invoice.where(status: :finalized).to_a

# Mark some older invoices as sent
sent_invoices = finalized_invoices.select { |i| i.date < 2.months.ago }.sample(5)
sent_invoices.each do |invoice|
  invoice.update!(status: :sent)
  puts "  Marked invoice #{invoice.number} as sent"
end

# Cancel a couple of invoices
cancelled_invoices = finalized_invoices.reject { |i| sent_invoices.include?(i) }.sample(2)
cancelled_invoices.each do |invoice|
  invoice.update!(status: :cancelled)
  puts "  Marked invoice #{invoice.number} as cancelled"
end

# Create payments for finalized/sent invoices (not cancelled)
puts "Creating payments..."
Invoice.where(status: %i[finalized sent]).find_each do |invoice|
  # Calculate total with tax from line items
  invoice_total = invoice.line_items.sum(&:total)

  # 75% chance of full payment, 15% partial, 10% unpaid
  payment_chance = rand(100)

  if payment_chance < 75
    # Full payment
    payment = create(:payment,
                     lease: invoice.lease,
                     date: invoice.date + rand(1..15).days,
                     amount: invoice_total)
    PaymentService.new(payment).call
    puts "  Paid invoice #{invoice.number}: #{invoice_total}"
  elsif payment_chance < 90
    # Partial payment
    partial_amount = (invoice_total * rand(0.3..0.7)).round(2)
    payment = create(:payment,
                     lease: invoice.lease,
                     date: invoice.date + rand(1..15).days,
                     amount: partial_amount)
    PaymentService.new(payment).call
    puts "  Partial payment for invoice #{invoice.number}: #{partial_amount} of #{invoice_total}"
  else
    puts "  Invoice #{invoice.number} remains unpaid: #{invoice_total}"
  end
end

# Create some unallocated payments (excess payments for testing)
puts "Creating excess payments..."
2.times do
  lease = leases.sample[:lease]
  excess_amount = Faker::Number.between(from: 500, to: 2000).round(-2)
  payment = create(:payment,
                   lease: lease,
                   date: Date.current - rand(1..10).days,
                   amount: excess_amount)
  # Don't allocate - leave as excess
  puts "  Created unallocated payment of #{excess_amount} for #{lease.property.name}"
end

puts "\nSeed completed!"
puts "  Owners: #{Owner.count}"
puts "  Properties: #{Property.count}"
puts "  Tenants: #{Tenant.count}"
puts "  Leases: #{Lease.count}"
puts "  Invoices: #{Invoice.count} (#{Invoice.draft.count} draft, #{Invoice.finalized.count} finalized, #{Invoice.sent.count} sent, #{Invoice.cancelled.count} cancelled)"
puts "  Payments: #{Payment.count}"
puts "  Users: #{User.count}"
puts "\nTest scenarios:"
puts "  - Properties without leases: #{Property.left_joins(:leases).where(leases: { id: nil }).count}"
puts "  - Leases with missing invoices (for generate testing): #{Lease.all.count { |l| l.missing_invoice_months.any? }}"
puts "  - Terminated leases: #{Lease.where.not(terminated_on: nil).count}"
puts "  - Unpaid/partially paid invoices: #{Invoice.where(status: %i[finalized sent partially_paid]).count}"
puts "\nLogin credentials:"
puts "  Admin: admin@example.com (use 'admin' as name in developer login)"
puts "  User: user@example.com (use 'user' as name in developer login) - has access to 2 owners"
