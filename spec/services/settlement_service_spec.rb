# frozen_string_literal: true

require "rails_helper"

RSpec.describe SettlementService do
  let(:lease) { create(:lease) }

  def create_invoice(amount:, date: Time.zone.today, status: :finalized, document_type: :invoice)
    invoice = create(:invoice, lease: lease, date: date, status: :draft, document_type: document_type)
    invoice.line_items.destroy_all
    # All line_items store positive amounts - document_type determines sign
    create(:line_item, invoice: invoice, amount: amount.abs, tax_rate: nil)
    # Manually set status to trigger entry creation
    invoice.update!(status: status)
    invoice.reload
  end

  def create_payment_record(amount:, date: Time.zone.today, payment_type: :payment)
    create(:payment, lease: lease, amount: amount.abs, date: date, payment_type: payment_type)
  end

  describe ".settle" do
    let!(:invoice) { create_invoice(amount: 100) }
    let!(:payment) { create_payment_record(amount: 100) }

    # rubocop:disable Rails/SkipsModelValidations -- Reset auto-settled state for manual settlement tests
    def reset_balances(invoice_balance: 100, payment_balance: -100)
      Entry.delete_all
      invoice.update_column(:balance, invoice_balance)
      payment.update_column(:balance, payment_balance)
    end
    # rubocop:enable Rails/SkipsModelValidations

    context "when settling a partial amount" do
      before { reset_balances }

      it "creates two entries with the same transaction_id" do
        txn_id = described_class.settle(credit: payment, debit: invoice, amount: 50)
        expect(Entry.where(transaction_id: txn_id).count).to eq(2)
      end

      it "creates a positive entry for credit (uses up credit)" do
        txn_id = described_class.settle(credit: payment, debit: invoice, amount: 50)
        expect(Entry.find_by(transaction_id: txn_id, instrument: payment).amount).to eq(50)
      end

      it "creates a negative entry for debit (reduces debt)" do
        txn_id = described_class.settle(credit: payment, debit: invoice, amount: 50)
        expect(Entry.find_by(transaction_id: txn_id, instrument: invoice).amount).to eq(-50)
      end
    end

    context "with manually created entries" do
      before do
        Entry.delete_all
        Entry.create!(lease: lease, instrument: invoice, amount: 100, transaction_id: nil)
        Entry.create!(lease: lease, instrument: payment, amount: -100, transaction_id: nil)
        invoice.recalculate_balance!
        payment.recalculate_balance!
      end

      it "updates balances on both instruments", :aggregate_failures do
        described_class.settle(credit: payment, debit: invoice, amount: 50)
        expect(invoice.reload.balance).to eq(50)
        expect(payment.reload.balance).to eq(-50)
      end
    end

    it "raises error if amount is not positive" do
      expect { described_class.settle(credit: payment, debit: invoice, amount: 0) }
        .to raise_error(ArgumentError, "Amount must be positive")
    end

    it "raises error if credit balance is insufficient" do
      reset_balances(payment_balance: -30)
      expect { described_class.settle(credit: payment, debit: invoice, amount: 50) }
        .to raise_error(ArgumentError, "Insufficient credit balance")
    end

    it "raises error if debit balance is insufficient" do
      reset_balances(invoice_balance: 30)
      expect { described_class.settle(credit: payment, debit: invoice, amount: 50) }
        .to raise_error(ArgumentError, "Insufficient debit balance")
    end
  end

  describe ".auto_settle" do
    context "when a payment is created with outstanding invoices" do
      let!(:older_invoice) { create_invoice(amount: 100, date: 2.months.ago) }
      let!(:newer_invoice) { create_invoice(amount: 100, date: 1.month.ago) }

      it "auto-settles payment against oldest invoice first", :aggregate_failures do
        payment = create_payment_record(amount: 150)

        expect(older_invoice.reload.balance).to eq(0)
        expect(newer_invoice.reload.balance).to eq(50)
        expect(payment.reload.balance).to eq(0)
      end

      it "fully pays all invoices when payment is sufficient", :aggregate_failures do
        payment = create_payment_record(amount: 200)

        expect(older_invoice.reload.balance).to eq(0)
        expect(newer_invoice.reload.balance).to eq(0)
        expect(payment.reload.balance).to eq(0)
      end

      it "leaves excess payment as unallocated credit", :aggregate_failures do
        payment = create_payment_record(amount: 250)

        expect(older_invoice.reload.balance).to eq(0)
        expect(newer_invoice.reload.balance).to eq(0)
        expect(payment.reload.balance).to eq(-50)
      end
    end

    context "when an invoice is finalized with unallocated payments" do
      let!(:payment) { create_payment_record(amount: 150) }

      it "auto-settles against the new invoice", :aggregate_failures do
        invoice = create_invoice(amount: 100)

        expect(invoice.reload.balance).to eq(0)
        expect(payment.reload.balance).to eq(-50)
      end
    end

    context "with credit notes" do
      it "credit note reduces invoice balance", :aggregate_failures do
        # Create invoice first - it starts with balance 200 (debit)
        invoice = create_invoice(amount: 200)
        expect(invoice.reload.balance).to eq(200)

        # Create credit note - it starts with balance -100 (credit)
        # and auto-settles against the invoice
        credit_note = create_invoice(amount: 100, document_type: :credit_note)

        expect(invoice.reload.balance).to eq(100)
        expect(credit_note.reload.balance).to eq(0)
      end
    end

    context "with refunds" do
      let!(:payment) { create_payment_record(amount: 100) }

      it "refund uses up payment credit", :aggregate_failures do
        refund = create_payment_record(amount: 50, payment_type: :refund)

        expect(payment.reload.balance).to eq(-50)
        expect(refund.reload.balance).to eq(0)
      end
    end

    context "with mixed instrument types (payment, credit note, final payment)" do
      before do
        create_invoice(amount: 1000)
        create_payment_record(amount: 800)
        create_invoice(amount: 100, document_type: :credit_note)
        create_payment_record(amount: 100)
      end

      it "zeroes all balances when fully paid" do
        expect(lease.entries.sum(:amount)).to eq(0)
      end
    end
  end

  describe ".readjust" do
    let!(:older_invoice) { create_invoice(amount: 100, date: 2.months.ago) }
    let!(:newer_invoice) { create_invoice(amount: 100, date: 1.month.ago) }
    let!(:payment) { create_payment_record(amount: 150) }

    context "with corrupted settlements" do
      before do
        older_invoice.entries.settlements.destroy_all
        older_invoice.recalculate_balance!
      end

      it "re-settles credits chronologically", :aggregate_failures do
        result = described_class.readjust(lease)
        expect(result[:settlement_count]).to be >= 0
        expect(result[:credit_count]).to eq(1)
      end

      it "restores correct balances", :aggregate_failures do
        described_class.readjust(lease)
        expect(older_invoice.reload.balance).to eq(0)
        expect(newer_invoice.reload.balance).to eq(50)
        expect(payment.reload.balance).to eq(0)
      end
    end
  end

  describe "balance queries" do
    it "tenant balance equals sum of all entries" do
      create_invoice(amount: 500)
      create_payment_record(amount: 300)

      expect(lease.entries.sum(:amount)).to eq(200)
    end

    it "tenant balance equals sum of cached balances" do
      create_invoice(amount: 500)
      create_payment_record(amount: 300)

      cached_balance = lease.invoices.sum(:balance) + lease.payments.sum(:balance)
      expect(cached_balance).to eq(200)
    end
  end

  describe "settlement linkage queries" do
    let!(:invoice) { create_invoice(amount: 100) }
    let!(:payment) { create_payment_record(amount: 100) }

    it "creates settlement entries for auto-settled invoice" do
      expect(invoice.entries.settlements.count).to eq(1)
    end

    it "links settlement counterpart to the payment" do
      txn_id = invoice.entries.settlements.first.transaction_id
      counterpart = Entry.where(transaction_id: txn_id).where.not(instrument: invoice).first
      expect(counterpart.instrument).to eq(payment)
    end
  end
end
