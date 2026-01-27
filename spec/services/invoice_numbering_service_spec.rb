# frozen_string_literal: true

require "rails_helper"

RSpec.describe InvoiceNumberingService do
  subject(:service) { described_class.new(invoice) }

  let(:owner) { create(:owner, name: "John Smith", invoice_sequence: 10) }
  let(:property) { create(:property, owner: owner) }
  let(:lease) { create(:lease, property: property) }
  let(:invoice) { create(:invoice, lease: lease, status: :draft, number: nil) }

  describe "#call" do
    it "assigns a sequential number to the invoice" do
      aggregate_failures do
        expect { service.call }.to change { invoice.reload.number }.from(nil)
        expect(invoice.number).to match(/JOH-\d+/)
      end
    end

    it "increments the owner's sequence" do
      expect { service.call }.to change { owner.reload.invoice_sequence }.by(1)
    end

    it "formats number correctly (JOH-011)" do
      service.call
      expect(invoice.reload.number).to eq("JOH-011")
    end

    context "when already numbered" do
      before { invoice.update!(number: "EXISTING") }

      it "does not change number" do
        expect { service.call }.not_to(change { invoice.reload.number })
      end

      it "does not increment owner sequence" do
        expect { service.call }.not_to(change { owner.reload.invoice_sequence })
      end
    end
  end
end
