# frozen_string_literal: true

require "rails_helper"

RSpec.describe LeaseHelper do
  describe "#billable_months" do
    let(:lease) { build(:lease, start_date: Date.new(2023, 1, 15), duration_months: 3) }

    let(:expected_months) do
      [
        Date.new(2023, 1, 1),
        Date.new(2023, 2, 1),
        Date.new(2023, 3, 1)
      ]
    end

    it "returns an array of months covering the lease duration" do
      expect(helper.billable_months(lease)).to eq(expected_months)
    end

    it "handles nil start_date gracefully" do
      lease.start_date = nil
      expect(helper.billable_months(lease)).to eq([])
    end
  end

  describe "#statement_entries" do
    let(:lease) { create(:lease) }

    it "returns empty array for empty entries" do
      expect(helper.statement_entries([])).to eq([])
    end

    context "with finalized invoices and confirmed payments" do
      let!(:invoice) do
        inv = create(:invoice, lease: lease, date: Date.new(2025, 1, 15), status: :draft)
        create(:line_item, invoice: inv, amount: 1000, tax_rate: 0)
        inv.update!(status: :finalized)
        inv.reload
      end

      let!(:payment) do
        create(:payment, lease: lease, date: Date.new(2025, 1, 20), amount: 1000, status: :confirmed)
      end

      let(:entries) { lease.entries.initial.preload(:instrument) }
      let(:lines) { helper.statement_entries(entries) }

      it "sorts by date ascending" do
        dates = lines.map(&:date)
        expect(dates).to eq(dates.sort)
      end

      it "returns StatementLine objects" do
        expect(lines).to all(be_a(LeaseHelper::StatementLine))
      end

      it "accumulates running balance", :aggregate_failures do
        expect(lines.first.balance).to eq(1000) # invoice debit
        expect(lines.last.balance).to eq(0) # payment credit offsets
      end

      it "identifies invoice line as debit", :aggregate_failures do
        invoice_line = lines.find { |l| l.instrument == invoice }
        expect(invoice_line).to be_debit
        expect(invoice_line.debit_amount).to eq(1000)
        expect(invoice_line.credit_amount).to be_nil
      end

      it "identifies payment line as credit", :aggregate_failures do
        payment_line = lines.find { |l| l.instrument == payment }
        expect(payment_line).not_to be_debit
        expect(payment_line.credit_amount).to eq(1000)
        expect(payment_line.debit_amount).to be_nil
      end
    end

    context "with same-date entries" do
      let(:invoice) do
        inv = create(:invoice, lease: lease, date: Date.new(2025, 2, 1), status: :draft)
        create(:line_item, invoice: inv, amount: 500, tax_rate: 0)
        inv.update!(status: :finalized)
        inv.reload
      end

      let(:credit_note) do
        cn = create(:invoice, :credit_note, lease: lease, date: Date.new(2025, 2, 1), status: :draft)
        create(:line_item, invoice: cn, amount: 100, tax_rate: 0)
        cn.update!(status: :finalized)
        cn.reload
      end

      let(:payment) do
        create(:payment, lease: lease, date: Date.new(2025, 2, 1), amount: 300, status: :confirmed)
      end

      let(:lines) do
        invoice
        credit_note
        payment
        helper.statement_entries(lease.entries.initial.preload(:instrument))
      end

      it "sorts by type within same date: invoice, credit_note, payment, refund" do
        expect(lines.map { |l| l.instrument.is_a?(Invoice) ? l.instrument.document_type : l.instrument.payment_type })
          .to eq(%w[invoice credit_note payment])
      end
    end
  end

  describe LeaseHelper::StatementLine do
    let(:lease) { create(:lease) }

    context "with an invoice" do
      let(:invoice) do
        inv = create(:invoice, lease: lease, date: Date.new(2025, 3, 1), status: :draft)
        create(:line_item, invoice: inv, amount: 2000, tax_rate: 0)
        inv.update!(status: :finalized)
        inv.reload
      end

      let(:entry) { invoice.entries.initial.first }
      let(:line) { described_class.new(entry: entry, balance: BigDecimal("2000")) }

      it "returns the instrument date" do
        expect(line.date).to eq(Date.new(2025, 3, 1))
      end

      it "returns invoice description with number" do
        expect(line.description).to match(/Invoice #\d+/)
      end

      it "returns correct icon and color", :aggregate_failures do
        expect(line.icon_name).to eq("document-text")
        expect(line.icon_color_class).to eq("text-warning")
        expect(line.accent_class).to eq("statement-invoice")
      end
    end

    context "with a credit note" do
      let(:credit_note) do
        cn = create(:invoice, :credit_note, lease: lease, date: Date.new(2025, 3, 1), status: :draft)
        create(:line_item, invoice: cn, amount: 500, tax_rate: 0)
        cn.update!(status: :finalized)
        cn.reload
      end

      let(:entry) { credit_note.entries.initial.first }
      let(:line) { described_class.new(entry: entry, balance: BigDecimal("-500")) }

      it "returns credit note description" do
        expect(line.description).to match(/Credit Note #\d+/)
      end

      it "returns correct icon and color", :aggregate_failures do
        expect(line.icon_name).to eq("document-minus")
        expect(line.icon_color_class).to eq("text-error")
        expect(line.accent_class).to eq("statement-credit-note")
      end

      it "is not a debit" do
        expect(line).not_to be_debit
      end
    end

    context "with a payment" do
      let(:payment) { create(:payment, lease: lease, date: Date.new(2025, 3, 15), amount: 1000) }
      let(:entry) { payment.entries.initial.first }
      let(:line) { described_class.new(entry: entry, balance: BigDecimal("-1000")) }

      it "returns payment description" do
        expect(line.description).to eq("Payment")
      end

      it "returns correct icon and color", :aggregate_failures do
        expect(line.icon_name).to eq("banknotes")
        expect(line.icon_color_class).to eq("text-success")
        expect(line.accent_class).to eq("statement-payment")
      end
    end

    context "with a refund" do
      let(:refund) { create(:payment, :refund, lease: lease, date: Date.new(2025, 3, 20), amount: 200) }
      let(:entry) { refund.entries.initial.first }
      let(:line) { described_class.new(entry: entry, balance: BigDecimal("200")) }

      it "returns refund description" do
        expect(line.description).to eq("Refund")
      end

      it "returns correct icon and color", :aggregate_failures do
        expect(line.icon_name).to eq("arrow-uturn-left")
        expect(line.icon_color_class).to eq("text-error")
        expect(line.accent_class).to eq("statement-refund")
      end

      it "is a debit" do
        expect(line).to be_debit
      end
    end
  end
end
