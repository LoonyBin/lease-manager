class RefactorLeaseEnhancementColumns < ActiveRecord::Migration[8.0]
  def up
    add_column :leases, :enhancement_amount, :decimal, precision: 10, scale: 2
    add_column :leases, :enhancement_type, :integer, default: 0

    Lease.reset_column_information
    Lease.find_each do |lease|
      if lease.enhancement_percentage.present? && lease.enhancement_percentage > 0
        lease.update_columns(enhancement_amount: lease.enhancement_percentage, enhancement_type: 0) # percentage
      elsif lease.enhancement_fixed_amount.present? && lease.enhancement_fixed_amount > 0
        lease.update_columns(enhancement_amount: lease.enhancement_fixed_amount, enhancement_type: 1) # fixed
      end
    end

    remove_column :leases, :enhancement_percentage
    remove_column :leases, :enhancement_fixed_amount
  end

  def down
    add_column :leases, :enhancement_percentage, :decimal
    add_column :leases, :enhancement_fixed_amount, :decimal

    Lease.reset_column_information
    Lease.find_each do |lease|
      if lease.enhancement_type == 0 # percentage
        lease.update_columns(enhancement_percentage: lease.enhancement_amount)
      else # fixed
        lease.update_columns(enhancement_fixed_amount: lease.enhancement_amount)
      end
    end

    remove_column :leases, :enhancement_amount
    remove_column :leases, :enhancement_type
  end
end
