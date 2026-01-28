class AddTaxRateToLineItems < ActiveRecord::Migration[8.0]
  def change
    add_column :line_items, :tax_rate, :decimal, precision: 5, scale: 3, default: 0
  end
end
