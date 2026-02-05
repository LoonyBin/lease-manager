class AddCreditNoteSequenceToOwners < ActiveRecord::Migration[8.1]
  def change
    add_column :owners, :credit_note_sequence, :integer, default: 0, null: false unless column_exists?(:owners, :credit_note_sequence)
  end
end
