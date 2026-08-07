# frozen_string_literal: true

class NarrowInvoiceTemplateDateUniqueIndex < ActiveRecord::Migration[8.1]
  # Only debit invoices reserve a template's month; a template-linked credit
  # note may now sit at the same (template, date) as the month's real invoice.
  # See #163.
  def up
    remove_index :invoices, name: "index_invoices_on_invoice_template_id_and_date"
    add_index :invoices, %i[invoice_template_id date], unique: true,
              where: "invoice_template_id IS NOT NULL AND document_type = 0",
              name: "index_invoices_on_invoice_template_id_and_date"
  end

  # Best-effort only: re-widening the predicate CANNOT succeed once a
  # template-linked credit note shares a (template, date) with a debit invoice,
  # because the wider index would then see a duplicate. Loosening in +up+ is
  # always safe (it strictly shrinks the indexed set); tightening here is not.
  def down
    remove_index :invoices, name: "index_invoices_on_invoice_template_id_and_date"
    add_index :invoices, %i[invoice_template_id date], unique: true,
              where: "invoice_template_id IS NOT NULL",
              name: "index_invoices_on_invoice_template_id_and_date"
  end
end
