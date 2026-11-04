# frozen_string_literal: true

require "rails_helper"

# The JSON preview must pick what the HTML form prefills. Both requests run as
# the same admin and are compared on template, dates, line items and, for an
# already saved invoice, the record the form would update.
RSpec.describe "Invoice preview matches GET /invoices/new" do
  let(:no_invoice) { { template_id: nil, date: nil, due_date: nil, target: nil } }
  let(:lease) { create(:lease) }
  let(:date) { lease.start_date.next_month.beginning_of_month }
  let(:second_template) { create(:invoice_template, :maintenance_only, lease: lease) }

  before do
    lease
    second_template
    sign_in_admin
  end

  def form_state(on: date, extra: {})
    get new_invoice_path(invoice: { lease_id: lease.id, date: on.iso8601 }.merge(extra))
    doc = response.parsed_body
    form_header(doc).merge(items: doc.css("tbody tr").filter_map { |row| form_line(row) })
  end

  def form_header(doc)
    {
      template_id: doc.at_css("input[name='invoice[invoice_template_id]']")&.[]("value").presence&.to_i,
      date: main_form_value(doc, "date"),
      due_date: main_form_value(doc, "due_date"),
      target: form_target(doc)
    }
  end

  # The page also has a GET prefill picker with its own invoice[date] input, so
  # read dates from the form that carries the due date.
  def main_form(doc)
    doc.at_css("form:has(input[name='invoice[due_date]'])")
  end

  def main_form_value(doc, field)
    main_form(doc)&.at_css("input[name='invoice[#{field}]']")&.[]("value").presence
  end

  # "create" for an unsaved draft, otherwise the path of the saved invoice the
  # form would update.
  def form_target(doc)
    action = main_form(doc)&.[]("action")
    return unless action

    action == invoices_path ? "create" : action
  end

  def form_line(row)
    field = ->(name) { row.at_css("input[name$='[#{name}]']")&.[]("value") }
    return unless field.call("name")

    [field.call("name"), field.call("category"), field.call("amount").to_d, field.call("tax_rate").to_d]
  end

  def json_state(on: date, extra: {})
    get lease_invoice_preview_path(lease, format: :json), params: { date: on.iso8601 }.merge(extra)
    invoice = response.parsed_body["invoice"]
    {
      template_id: invoice&.fetch("invoice_template_id"),
      date: invoice&.fetch("date"),
      due_date: invoice&.fetch("due_date"),
      target: invoice && (invoice["id"] ? invoice_path(invoice["id"]) : "create"),
      items: json_items(invoice)
    }
  end

  def json_items(invoice)
    Array(invoice&.fetch("line_items")).map do |line|
      [line["name"], line["category"], line["amount"].to_d, line["tax_rate"].to_d]
    end
  end

  it "matches for the default template" do
    expect(json_state).to eq(form_state)
  end

  it "matches for an explicit template" do
    extra = { invoice_template_id: second_template.id }
    expect(json_state(extra: extra)).to eq(form_state(extra: extra))
  end

  it "matches for a stale template id (blank form, no invoice)" do
    extra = { invoice_template_id: 0 }
    expect(json_state(extra: extra)).to eq(form_state(extra: extra).merge(no_invoice))
  end

  it "matches outside the template window" do
    outside = lease.start_date - 2.years
    expect(json_state(on: outside)).to eq(form_state(on: outside).merge(no_invoice))
  end

  it "matches when the first template is already billed" do
    TemplateInvoiceGenerator.new(lease.invoice_templates.order(:id).first, date).call.save!
    expect(json_state).to eq(form_state)
  end

  it "matches a saved invoice when every template is already billed" do
    lease.invoice_templates.order(:id).each { |t| TemplateInvoiceGenerator.new(t, date).call.save! }
    expect(json_state).to eq(form_state)
  end

  it "targets the saved invoice record when every template is already billed" do
    lease.invoice_templates.order(:id).each { |t| TemplateInvoiceGenerator.new(t, date).call.save! }
    expect(json_state[:target]).to match(%r{\A/invoices/\d+\z})
  end

  it "is not masked by a template-linked credit note" do
    create(:invoice, :credit_note, lease: lease, invoice_template: lease.invoice_templates.order(:id).first, date: date)
    expect(json_state).to eq(form_state)
  end

  # The expression is broken after validation, as happens when a variable is
  # later removed, so it fails through the generator's normal evaluation path.
  it "matches when an amount expression fails (blank form, no invoice)" do
    lease.invoice_templates.order(:id).first.line_items.first.update_column(:amount_expression, "no_such_variable") # rubocop:disable Rails/SkipsModelValidations
    expect(json_state).to eq(form_state.merge(no_invoice))
  end

  it "picks the second template when the first is already billed" do
    TemplateInvoiceGenerator.new(lease.invoice_templates.order(:id).first, date).call.save!
    expect(json_state[:template_id]).to eq(second_template.id)
  end
end
