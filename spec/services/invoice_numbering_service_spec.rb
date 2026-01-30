# frozen_string_literal: true

require "rails_helper"

RSpec.describe InvoiceNumberingService do
  describe "#call" do
    it "assigns a sequential number to the invoice instance" do
      invoice = create(:invoice, status: :draft, number: nil)
      invoice.lease.property.owner.update!(name: "John Smith", invoice_sequence: 10)

      described_class.new(invoice).call

      expect(invoice.number).to eq("JOH-011")
    end

    it "increments the owner's invoice_sequence" do
      invoice = create(:invoice, status: :draft, number: nil)
      owner = invoice.lease.property.owner
      owner.update!(invoice_sequence: 10)

      expect { described_class.new(invoice).call }.to change { owner.reload.invoice_sequence }.from(10).to(11)
    end

    context "when already numbered" do
      it "does not change number" do
        invoice = create(:invoice, status: :draft, number: "EXISTING")
        expect { described_class.new(invoice).call }.not_to(change { invoice.reload.number })
      end

      it "does not increment owner sequence" do
        invoice = create(:invoice, status: :draft, number: "EXISTING")
        owner = invoice.lease.property.owner
        expect { described_class.new(invoice).call }.not_to(change { owner.reload.invoice_sequence })
      end
    end
  end
end
