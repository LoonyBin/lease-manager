class AddPrefixesToOwners < ActiveRecord::Migration[8.1]
  def change
    add_column :owners, :invoice_prefix, :string
    add_column :owners, :credit_note_prefix, :string

    Owner.find_each do |owner|
      prefix = owner.name.gsub(/[^a-zA-Z]/, "").upcase[0..2]
      prefix = "OWN" if prefix.blank?
      prefix += "-"
      cn_prefix = "CN-#{prefix}"
      owner.update_columns(invoice_prefix: prefix, credit_note_prefix: cn_prefix)
    end
  end
end
