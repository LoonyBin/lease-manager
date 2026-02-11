# frozen_string_literal: true

require "rails_helper"
require "rake"

RSpec.describe "settlements:readjust", type: :task do # -- Rake task spec
  before(:all) do # rubocop:disable RSpec/BeforeAfterAll -- Rake tasks only need loading once
    Rails.application.load_tasks
  end

  let(:lease) { create(:lease) }

  def create_invoice(amount:, date: Time.zone.today, status: :finalized, document_type: :invoice)
    invoice = create(:invoice, lease: lease, date: date, status: :draft, document_type: document_type)
    invoice.line_items.destroy_all
    create(:line_item, invoice: invoice, amount: amount.abs, tax_rate: nil)
    invoice.update!(status: status)
    invoice.reload
  end

  def create_payment_record(amount:, date: Time.zone.today, payment_type: :payment)
    create(:payment, lease: lease, amount: amount.abs, date: date, payment_type: payment_type)
  end

  around do |example|
    original = ENV.fetch("LEASE_ID", nil)
    example.run
  ensure
    ENV["LEASE_ID"] = original
    Rake::Task["settlements:readjust"].reenable
  end

  it "aborts when LEASE_ID is not provided" do
    ENV.delete("LEASE_ID")
    expect { Rake::Task["settlements:readjust"].invoke }.to raise_error(SystemExit)
  end

  it "aborts when LEASE_ID is invalid" do
    ENV["LEASE_ID"] = "999999"
    expect { Rake::Task["settlements:readjust"].invoke }.to raise_error(SystemExit)
  end

  # rubocop:disable RSpec/ExampleLength, RSpec/MultipleExpectations -- Integration test
  it "re-adjusts settlements for the given lease" do
    older_invoice = create_invoice(amount: 100, date: 2.months.ago)
    newer_invoice = create_invoice(amount: 100, date: 1.month.ago)
    payment = create_payment_record(amount: 150)

    # Verify initial auto-settle state
    expect(older_invoice.reload.balance).to eq(0)
    expect(newer_invoice.reload.balance).to eq(50)
    expect(payment.reload.balance).to eq(0)

    # Manually corrupt settlements by deleting some entries
    older_invoice.entries.settlements.destroy_all
    older_invoice.recalculate_balance!

    # Now older_invoice has balance 100 (unsettled) — inconsistent state
    expect(older_invoice.reload.balance).to eq(100)

    ENV["LEASE_ID"] = lease.id.to_s
    expect { Rake::Task["settlements:readjust"].invoke }.to output(/Readjusted settlements/).to_stdout

    # After readjust, settlements should be back to correct state
    expect(older_invoice.reload.balance).to eq(0)
    expect(newer_invoice.reload.balance).to eq(50)
    expect(payment.reload.balance).to eq(0)
  end

  it "preserves total balance across readjustment" do
    create_invoice(amount: 500, date: 2.months.ago)
    create_payment_record(amount: 300, date: 1.month.ago)

    total_before = lease.entries.sum(:amount)

    ENV["LEASE_ID"] = lease.id.to_s
    expect { Rake::Task["settlements:readjust"].invoke }.to output.to_stdout

    expect(lease.entries.sum(:amount)).to eq(total_before)
  end

  it "handles lease with no settlements gracefully" do
    # Draft invoice — won't create entries
    create(:invoice, lease: lease, date: Time.zone.today, status: :draft)

    ENV["LEASE_ID"] = lease.id.to_s
    expect { Rake::Task["settlements:readjust"].invoke }.to output(/Readjusted settlements/).to_stdout
  end
  # rubocop:enable RSpec/ExampleLength, RSpec/MultipleExpectations
end
