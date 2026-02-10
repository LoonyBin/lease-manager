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

    # rubocop:disable RSpec/ExampleLength -- Test setup requires multiple steps
    it "creates two entries with the same transaction_id" do
      # Clear any auto-settled entries first
      Entry.delete_all
      invoice.update_column(:balance, 100) # rubocop:disable Rails/SkipsModelValidations -- Test setup
      payment.update_column(:balance, -100) # rubocop:disable Rails/SkipsModelValidations -- Test setup

      txn_id = described_class.settle(credit: payment, debit: invoice, amount: 50)

      entries = Entry.where(transaction_id: txn_id)
      expect(entries.count).to eq(2)
    end

    it "creates a positive entry for credit (uses up credit)" do
      Entry.delete_all
      invoice.update_column(:balance, 100) # rubocop:disable Rails/SkipsModelValidations -- Test setup
      payment.update_column(:balance, -100) # rubocop:disable Rails/SkipsModelValidations -- Test setup

      txn_id = described_class.settle(credit: payment, debit: invoice, amount: 50)

      payment_entry = Entry.find_by(transaction_id: txn_id, instrument: payment)
      expect(payment_entry.amount).to eq(50)
    end

    it "creates a negative entry for debit (reduces debt)" do
      Entry.delete_all
      invoice.update_column(:balance, 100) # rubocop:disable Rails/SkipsModelValidations -- Test setup
      payment.update_column(:balance, -100) # rubocop:disable Rails/SkipsModelValidations -- Test setup

      txn_id = described_class.settle(credit: payment, debit: invoice, amount: 50)

      invoice_entry = Entry.find_by(transaction_id: txn_id, instrument: invoice)
      expect(invoice_entry.amount).to eq(-50)
    end

    it "updates balances on both instruments", :aggregate_failures do
      Entry.delete_all
      # Create initial entries to set up balances
      Entry.create!(lease: lease, instrument: invoice, amount: 100, transaction_id: nil)
      Entry.create!(lease: lease, instrument: payment, amount: -100, transaction_id: nil)
      invoice.recalculate_balance!
      payment.recalculate_balance!

      described_class.settle(credit: payment, debit: invoice, amount: 50)

      # Invoice (debit): started at 100, added -50 settlement = 50 remaining debt
      expect(invoice.reload.balance).to eq(50)
      # Payment (credit): started at -100, added +50 settlement = -50 remaining credit
      expect(payment.reload.balance).to eq(-50)
    end
    # rubocop:enable RSpec/ExampleLength

    it "raises error if amount is not positive" do
      expect { described_class.settle(credit: payment, debit: invoice, amount: 0) }
        .to raise_error(ArgumentError, "Amount must be positive")
    end

    it "raises error if credit balance is insufficient" do
      Entry.delete_all
      payment.update_column(:balance, -30) # rubocop:disable Rails/SkipsModelValidations -- Test setup
      invoice.update_column(:balance, 100) # rubocop:disable Rails/SkipsModelValidations -- Test setup

      expect { described_class.settle(credit: payment, debit: invoice, amount: 50) }
        .to raise_error(ArgumentError, "Insufficient credit balance")
    end

    it "raises error if debit balance is insufficient" do
      Entry.delete_all
      payment.update_column(:balance, -100) # rubocop:disable Rails/SkipsModelValidations -- Test setup
      invoice.update_column(:balance, 30) # rubocop:disable Rails/SkipsModelValidations -- Test setup

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

    context "with multiple instrument types" do
      # rubocop:disable RSpec/ExampleLength -- Integration test verifying complete flow
      it "correctly balances all instruments", :aggregate_failures do
        # Create invoice for 1000
        invoice = create_invoice(amount: 1000)
        expect(invoice.reload.balance).to eq(1000)

        # Payment of 800
        payment = create_payment_record(amount: 800)
        expect(invoice.reload.balance).to eq(200)
        expect(payment.reload.balance).to eq(0)

        # Credit note of 100
        credit_note = create_invoice(amount: 100, document_type: :credit_note)
        expect(invoice.reload.balance).to eq(100)
        expect(credit_note.reload.balance).to eq(0)

        # Final payment of 100 to clear the invoice
        final_payment = create_payment_record(amount: 100)
        expect(invoice.reload.balance).to eq(0)
        expect(final_payment.reload.balance).to eq(0)

        # Total tenant balance should be 0
        expect(lease.entries.sum(:amount)).to eq(0)
      end
      # rubocop:enable RSpec/ExampleLength
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
    # rubocop:disable RSpec/ExampleLength -- Integration test demonstrating query pattern
    it "can find what settled an invoice", :aggregate_failures do
      invoice = create_invoice(amount: 100)
      payment = create_payment_record(amount: 100)

      # Get settlement entries for the invoice
      settlement_entries = invoice.entries.settlements

      expect(settlement_entries.count).to eq(1)

      # Find counterpart
      txn_id = settlement_entries.first.transaction_id
      counterparts = Entry.where(transaction_id: txn_id).where.not(instrument: invoice)

      expect(counterparts.first.instrument).to eq(payment)
    end
    # rubocop:enable RSpec/ExampleLength
  end
end
