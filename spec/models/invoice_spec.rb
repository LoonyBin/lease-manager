# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoice do
  describe "associations" do
    it { is_expected.to belong_to(:lease) }
    it { is_expected.to have_many(:line_items).dependent(:destroy) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:date) }
    it { is_expected.to validate_presence_of(:status) }

    it {
      is_expected.to define_enum_for(:status).with_values(draft: 0, finalized: 1, sent: 2, paid: 3, cancelled: 4,
                                                          partially_paid: 5)
    }
  end

  describe "callbacks" do
    let(:invoice) { create(:invoice, status: :draft, number: nil) }

    describe "number assignment" do
      it "assigns number before save when finalizing" do
        service = instance_double(InvoiceNumberingService)
        allow(InvoiceNumberingService).to receive(:new).with(invoice).and_return(service)
        allow(service).to receive(:call)

        invoice.update status: :finalized

        expect(service).to have_received(:call)
      end

      it "does not assign number if already present" do
        invoice.update(number: "INV-001")
        service = instance_double(InvoiceNumberingService)
        allow(InvoiceNumberingService).to receive(:new).with(invoice).and_return(service)

        invoice.update status: :finalized

        expect(InvoiceNumberingService).not_to have_received(:new)
      end

      it "does not assign number if not finalizing" do
        service = instance_double(InvoiceNumberingService)
        allow(InvoiceNumberingService).to receive(:new).with(invoice).and_return(service)

        invoice.save # status is still draft

        expect(InvoiceNumberingService).not_to have_received(:new)
      end
    end

    describe "payment allocation" do
      it "allocates excess payment after save when finalizing" do
        allow(PaymentService).to receive(:allocate_excess)

        invoice.update status: :finalized

        expect(PaymentService).to have_received(:allocate_excess).with(invoice)
      end

      it "does not allocate payment if not finalizing" do
        allow(PaymentService).to receive(:allocate_excess)

        invoice.save # status is still draft

        expect(PaymentService).not_to have_received(:allocate_excess)
      end

      it "does not allocate payment if already finalized and just updating other fields" do
        invoice.update(status: :finalized, number: "123")
        allow(PaymentService).to receive(:allocate_excess)

        invoice.update(date: Date.tomorrow)

        expect(PaymentService).not_to have_received(:allocate_excess)
      end
    end
  end
end
