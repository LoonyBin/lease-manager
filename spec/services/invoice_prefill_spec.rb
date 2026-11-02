# frozen_string_literal: true

require "rails_helper"

RSpec.describe InvoicePrefill do
  let(:lease) { create(:lease) }
  let(:date) { lease.start_date.next_month.beginning_of_month }
  let(:template_id) { nil }
  let(:result) { described_class.new(lease: lease, date: date, invoice_template_id: template_id).call }
  let(:second_template) { create(:invoice_template, :maintenance_only, lease: lease) }

  # Eager so the lease's after_create side effects don't run inside count blocks.
  before do
    lease
    second_template
  end

  it "builds an unsaved draft from the first template", :aggregate_failures do
    expect(result.reason).to be_nil
    expect(result.invoice).to be_new_record
    expect(result.invoice.invoice_template).to eq(lease.invoice_templates.order(:id).first)
  end

  it "saves nothing" do
    expect { result }.not_to(change { [Invoice.count, LineItem.count] })
  end

  context "when the month is already billed by every template" do
    it "returns the first template's existing invoice" do
      existing = lease.invoice_templates.order(:id).map { |t| TemplateInvoiceGenerator.new(t, date).call.tap(&:save!) }
      expect(result.invoice).to eq(existing.first)
    end
  end

  context "when the first template is already billed" do
    before { TemplateInvoiceGenerator.new(lease.invoice_templates.order(:id).first, date).call.save! }

    it "picks the next uninvoiced template" do
      expect(result.invoice.invoice_template).to eq(second_template)
    end
  end

  context "with an explicit invoice_template_id" do
    let(:template_id) { second_template.id }

    it "uses that template" do
      expect(result.invoice.invoice_template_id).to eq(template_id)
    end
  end

  context "with a template id from another lease" do
    let(:template_id) { create(:lease).invoice_templates.first.id }

    it "reports template_not_found", :aggregate_failures do
      expect(result.invoice).to be_nil
      expect(result.reason).to eq(:template_not_found)
    end
  end

  context "when the lease has no templates" do
    before { lease.invoice_templates.destroy_all }

    it "reports no_template", :aggregate_failures do
      expect(result.invoice).to be_nil
      expect(result.reason).to eq(:no_template)
    end
  end

  context "when the month is outside every template's window" do
    let(:date) { lease.start_date.beginning_of_month - 2.years }

    it "reports not_generated", :aggregate_failures do
      expect(result.invoice).to be_nil
      expect(result.reason).to eq(:not_generated)
    end
  end

  context "when an amount expression fails" do
    before do
      allow_any_instance_of(TemplateInvoiceGenerator).to receive(:call) # rubocop:disable RSpec/AnyInstance
        .and_raise(InvoiceTemplates::EvaluationError, "boom")
    end

    it "reports evaluation_error", :aggregate_failures do
      expect(result.invoice).to be_nil
      expect(result.reason).to eq(:evaluation_error)
    end
  end
end
