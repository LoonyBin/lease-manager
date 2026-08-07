# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoice do
  describe "associations" do
    it { is_expected.to belong_to(:lease) }
    it { is_expected.to belong_to(:invoice_template).optional }
    it { is_expected.to have_many(:line_items).dependent(:destroy) }
    it { is_expected.to have_many(:entries).dependent(:destroy) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:date) }
    it { is_expected.to validate_presence_of(:status) }

    it "accepts an invoice template belonging to the invoice's lease" do
      lease = create(:lease)
      invoice = build(:invoice, lease: lease, invoice_template: lease.invoice_templates.first)
      expect(invoice).to be_valid
    end

    it "rejects an invoice template from another lease", :aggregate_failures do
      invoice = build(:invoice, lease: create(:lease), invoice_template: create(:lease).invoice_templates.first)
      expect(invoice).not_to be_valid
      expect(invoice.errors[:invoice_template]).to include("must belong to the invoice's lease")
    end

    it "rejects a dangling invoice template id" do
      invoice = build(:invoice, lease: create(:lease), invoice_template_id: -1)
      expect(invoice).not_to be_valid
    end

    it {
      is_expected.to define_enum_for(:status).with_values(draft: 0, finalized: 1, sent: 2, paid: 3, cancelled: 4,
                                                          partially_paid: 5)
    }

    it {
      is_expected.to define_enum_for(:document_type).with_values(invoice: 0, credit_note: 1)
    }
  end

  describe "template + date uniqueness" do
    let(:lease) { create(:lease) }
    let(:template) { lease.invoice_templates.first }
    let(:date) { Date.new(2026, 1, 1) }

    before { create(:invoice, lease: lease, invoice_template: template, date: date) }

    it "rejects a second debit invoice for the same template and date", :aggregate_failures do
      duplicate = build(:invoice, lease: lease, invoice_template: template, date: date)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:date]).to be_present
    end

    it "allows a template-linked credit note beside the month's debit invoice" do
      credit_note = build(:invoice, :credit_note, lease: lease, invoice_template: template, date: date)
      expect(credit_note).to be_valid
    end
  end

  describe "scopes" do
    let(:lease) { create(:lease) }

    describe ".covering" do
      let(:template) { lease.invoice_templates.first }
      let!(:cancelled) do
        create(:invoice, lease: lease, invoice_template: template, date: Date.new(2026, 1, 1), status: :cancelled)
      end
      let!(:credit_note) do
        create(:invoice, :credit_note, lease: lease, invoice_template: template, date: Date.new(2026, 2, 1))
      end

      it "includes cancelled debit invoices but excludes credit notes", :aggregate_failures do
        expect(described_class.covering).to include(cancelled)
        expect(described_class.covering).not_to include(credit_note)
      end
    end

    describe ".overdue" do
      it "includes unsettled invoices with due_date in the past" do
        invoice = create(:invoice, :with_balance, balance_amount: 100, lease: lease, status: :finalized,
                                                  due_date: 1.day.ago)
        expect(described_class.overdue).to include(invoice)
      end

      it "excludes invoices with due_date today or in the future" do
        invoice = create(:invoice, :with_balance, balance_amount: 100, lease: lease, status: :finalized,
                                                  due_date: Date.current)
        expect(described_class.overdue).not_to include(invoice)
      end

      it "excludes paid invoices" do
        invoice = create(:invoice, :with_balance, balance_amount: 0, lease: lease, status: :paid,
                                                  due_date: 1.day.ago)
        expect(described_class.overdue).not_to include(invoice)
      end

      it "excludes cancelled invoices" do
        invoice = create(:invoice, :with_balance, balance_amount: 100, lease: lease, status: :cancelled,
                                                  due_date: 1.day.ago)
        expect(described_class.overdue).not_to include(invoice)
      end
    end

    describe ".near_due" do
      it "includes unsettled invoices with due_date within 7 days" do
        invoice = create(:invoice, :with_balance, balance_amount: 100, lease: lease, status: :finalized,
                                                  due_date: 3.days.from_now)
        expect(described_class.near_due).to include(invoice)
      end

      it "includes invoices with due_date today" do
        invoice = create(:invoice, :with_balance, balance_amount: 100, lease: lease, status: :finalized,
                                                  due_date: Date.current)
        expect(described_class.near_due).to include(invoice)
      end

      it "includes invoices with due_date exactly 7 days from now" do
        invoice = create(:invoice, :with_balance, balance_amount: 100, lease: lease, status: :finalized,
                                                  due_date: 7.days.from_now)
        expect(described_class.near_due).to include(invoice)
      end

      it "excludes invoices with due_date beyond 7 days" do
        invoice = create(:invoice, :with_balance, balance_amount: 100, lease: lease, status: :finalized,
                                                  due_date: 8.days.from_now)
        expect(described_class.near_due).not_to include(invoice)
      end

      it "excludes paid invoices" do
        invoice = create(:invoice, :with_balance, balance_amount: 0, lease: lease, status: :paid,
                                                  due_date: Date.current)
        expect(described_class.near_due).not_to include(invoice)
      end
    end
  end

  describe "due_date default" do
    it "defaults due_date to date when not set" do
      invoice = build(:invoice, date: Date.new(2026, 1, 1), due_date: nil)
      invoice.valid?
      expect(invoice.due_date).to eq(Date.new(2026, 1, 1))
    end

    it "preserves due_date when explicitly set" do
      invoice = build(:invoice, date: Date.new(2026, 1, 1), due_date: Date.new(2026, 1, 15))
      invoice.valid?
      expect(invoice.due_date).to eq(Date.new(2026, 1, 15))
    end
  end

  describe "#overdue?" do
    let(:lease) { create(:lease) }

    it "returns true when unsettled and due_date is in the past" do
      invoice = create(:invoice, :with_balance, balance_amount: 100, lease: lease, status: :finalized,
                                                due_date: 1.day.ago)
      expect(invoice.overdue?).to be true
    end

    it "returns false when due_date is today" do
      invoice = build(:invoice, status: :finalized, due_date: Date.current)
      expect(invoice.overdue?).to be false
    end

    it "returns false when paid" do
      invoice = build(:invoice, status: :paid, due_date: 1.day.ago)
      expect(invoice.overdue?).to be false
    end

    it "returns false when cancelled" do
      invoice = build(:invoice, status: :cancelled, due_date: 1.day.ago)
      expect(invoice.overdue?).to be false
    end
  end

  describe "#near_due?" do
    it "returns true when unsettled and due_date within 7 days" do
      invoice = build(:invoice, status: :finalized, due_date: 3.days.from_now)
      expect(invoice.near_due?).to be true
    end

    it "returns true when due_date is today" do
      invoice = build(:invoice, status: :finalized, due_date: Date.current)
      expect(invoice.near_due?).to be true
    end

    it "returns false when due_date beyond 7 days" do
      invoice = build(:invoice, status: :finalized, due_date: 8.days.from_now)
      expect(invoice.near_due?).to be false
    end

    it "returns false when paid" do
      invoice = build(:invoice, status: :paid, due_date: Date.current)
      expect(invoice.near_due?).to be false
    end
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

    describe "initial entry creation" do
      let(:invoice) { create(:invoice, status: :draft) }

      before do
        invoice.line_items.destroy_all
        create(:line_item, invoice: invoice, amount: 100, tax_rate: nil)
      end

      it "creates an initial entry when finalized" do
        expect { invoice.update!(status: :finalized) }
          .to change { invoice.entries.initial.count }.by(1)
      end

      it "sets balance from entry amount" do
        invoice.update!(status: :finalized)
        expect(invoice.reload.balance).to eq(100)
      end

      it "does not create entry for draft invoices" do
        expect(invoice.entries.initial.count).to eq(0)
      end
    end

    describe "auto settlement" do
      before do
        invoice.line_items.destroy_all
        create(:line_item, invoice: invoice, amount: 100, tax_rate: nil)
      end

      it "auto-settles after save when finalizing" do
        allow(SettlementService).to receive(:auto_settle)

        invoice.update status: :finalized

        expect(SettlementService).to have_received(:auto_settle).with(invoice)
      end

      it "does not auto-settle if not finalizing" do
        allow(SettlementService).to receive(:auto_settle)

        invoice.save # status is still draft

        expect(SettlementService).not_to have_received(:auto_settle)
      end

      it "does not auto-settle if already finalized and just updating other fields" do
        invoice.update(status: :finalized, number: "123")
        allow(SettlementService).to receive(:auto_settle)

        invoice.update(date: Date.tomorrow)

        expect(SettlementService).not_to have_received(:auto_settle)
      end
    end
  end

  describe "#total_amount" do
    let(:invoice) { create(:invoice, status: :draft) }

    before { invoice.line_items.destroy_all }

    it "sums line item amounts when no tax" do
      create(:line_item, invoice: invoice, amount: 100, tax_rate: nil)
      expect(invoice.total_amount).to eq(100)
    end

    it "includes tax in the total" do
      create(:line_item, invoice: invoice, amount: 100, tax_rate: 18)
      expect(invoice.total_amount).to eq(118)
    end

    it "sums multiple line items with mixed tax rates" do
      create(:line_item, invoice: invoice, amount: 1000, tax_rate: 18)
      create(:line_item, invoice: invoice, amount: 500, tax_rate: nil)
      expect(invoice.total_amount).to eq(1680)
    end
  end

  describe "#signed_amount" do
    let(:invoice) { create(:invoice, status: :draft) }

    before do
      invoice.line_items.destroy_all
      create(:line_item, invoice: invoice, amount: 100, tax_rate: nil)
    end

    it "returns positive amount for regular invoices" do
      expect(invoice.signed_amount).to eq(100)
    end

    it "returns negative amount for credit notes" do
      invoice.update!(document_type: :credit_note)
      expect(invoice.signed_amount).to eq(-100)
    end
  end

  describe "#credit? and #debit?" do
    it "regular invoice is debit", :aggregate_failures do
      invoice = build(:invoice, document_type: :invoice)
      expect(invoice.debit?).to be true
      expect(invoice.credit?).to be false
    end

    it "credit note is credit", :aggregate_failures do
      invoice = build(:invoice, document_type: :credit_note)
      expect(invoice.credit?).to be true
      expect(invoice.debit?).to be false
    end
  end

  describe "#recalculate_balance!" do
    let(:lease) { create(:lease) }
    let(:invoice) { create(:invoice, lease: lease, status: :draft) }

    before do
      invoice.line_items.destroy_all
      create(:line_item, invoice: invoice, amount: 100, tax_rate: nil)
      invoice.update!(status: :finalized)
    end

    it "updates balance from sum of entries", :aggregate_failures do
      expect(invoice.balance).to eq(100)

      # Simulate a settlement entry
      Entry.create!(lease: lease, instrument: invoice, amount: -50, transaction_id: SecureRandom.uuid)
      invoice.recalculate_balance!

      expect(invoice.reload.balance).to eq(50)
    end
  end

  describe "#update_status_from_balance!" do
    let(:lease) { create(:lease) }
    let(:invoice) { create(:invoice, lease: lease, status: :draft) }

    before do
      invoice.line_items.destroy_all
      create(:line_item, invoice: invoice, amount: 100, tax_rate: nil)
      invoice.update!(status: :finalized)
      invoice.entries.destroy_all # Clear for manual testing
    end

    context "when fully paid (balance <= 0)" do
      it "updates status to paid" do
        Entry.create!(lease: lease, instrument: invoice, amount: 100, transaction_id: nil)
        Entry.create!(lease: lease, instrument: invoice, amount: -100, transaction_id: SecureRandom.uuid)
        invoice.recalculate_balance!

        expect(invoice.reload.status).to eq("paid")
      end
    end

    context "when partially paid (0 < balance < total)" do
      it "updates status to partially_paid" do
        Entry.create!(lease: lease, instrument: invoice, amount: 100, transaction_id: nil)
        Entry.create!(lease: lease, instrument: invoice, amount: -40, transaction_id: SecureRandom.uuid)
        invoice.recalculate_balance!

        expect(invoice.reload.status).to eq("partially_paid")
      end
    end

    context "when unpaid (balance == total)" do
      it "keeps status as finalized" do
        Entry.create!(lease: lease, instrument: invoice, amount: 100, transaction_id: nil)
        invoice.recalculate_balance!

        expect(invoice.reload.status).to eq("finalized")
      end
    end

    context "when draft" do
      it "does not change status" do
        invoice.update_column(:status, described_class.statuses[:draft]) # rubocop:disable Rails/SkipsModelValidations
        invoice.update_status_from_balance!

        expect(invoice.reload.status).to eq("draft")
      end
    end

    context "when cancelled" do
      it "does not change status" do
        invoice.update_column(:status, described_class.statuses[:cancelled]) # rubocop:disable Rails/SkipsModelValidations
        invoice.update_status_from_balance!

        expect(invoice.reload.status).to eq("cancelled")
      end
    end
  end
end
