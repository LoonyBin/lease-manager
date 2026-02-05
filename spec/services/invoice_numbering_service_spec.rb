# frozen_string_literal: true

require "rails_helper"

RSpec.describe InvoiceNumberingService do
  describe "#call" do
    let(:lease) { create(:lease) }
    let(:owner) { lease.property.owner }

    context "with an invoice" do
      let(:invoice) { create(:invoice, lease: lease, status: :draft, number: nil, document_type: :invoice) }

      before do
        owner.update!(name: "John Smith", invoice_sequence: 10)
      end

      it "assigns a sequential number to the invoice instance" do
        described_class.new(invoice).call
        expect(invoice.number).to eq("JOH-011")
      end

      it "increments the owner's invoice_sequence" do
        expect { described_class.new(invoice).call }.to change { owner.reload.invoice_sequence }.from(10).to(11)
      end
    end

    context "with a credit note" do
      let(:credit_note) { create(:invoice, lease: lease, status: :draft, number: nil, document_type: :credit_note) }

      before do
        owner.update!(name: "John Smith", credit_note_sequence: 5)
      end

      it "assigns a sequential credit note number" do
        described_class.new(credit_note).call
        expect(credit_note.number).to eq("CN-JOH-006")
      end

      it "increments the owner's credit_note_sequence" do
        expect { described_class.new(credit_note).call }.to change { owner.reload.credit_note_sequence }.from(5).to(6)
      end

      it "does not increment the invoice_sequence" do
        expect { described_class.new(credit_note).call }.not_to(change { owner.reload.invoice_sequence })
      end
    end

    context "when already numbered" do
      it "does not change number" do
        invoice = create(:invoice, status: :draft, number: "EXISTING")
        expect { described_class.new(invoice).call }.not_to(change { invoice.reload.number })
      end
    end
  end
end
