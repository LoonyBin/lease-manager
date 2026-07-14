# frozen_string_literal: true

class AddInvoiceTemplateToInvoices < ActiveRecord::Migration[8.1]
  def change
    add_reference :invoices, :invoice_template, null: true, index: false,
                                                foreign_key: { on_delete: :nullify }
    add_index :invoices, %i[invoice_template_id date],
              unique: true,
              where: "invoice_template_id IS NOT NULL",
              name: "index_invoices_on_invoice_template_id_and_date"
  end
end
