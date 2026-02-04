# frozen_string_literal: true

class Payment < ApplicationRecord
  belongs_to :lease
  has_many :entries, as: :instrument, dependent: :destroy

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :date, presence: true
  validates :mode, presence: true

  enum :mode, {
    rtgs: 0,
    neft: 1,
    imps: 2,
    upi: 3,
    cheque: 4,
    cash: 5,
    demand_draft: 6,
    tax_deducted_at_source: 7
  }, default: :rtgs

  enum :payment_type, { payment: 0, refund: 1 }, default: :payment

  after_create :create_initial_entry
  after_create :auto_settle

  def credit?
    payment?
  end

  def debit?
    refund?
  end

  def signed_amount
    credit? ? -amount : amount
  end

  # rubocop:disable Rails/SkipsModelValidations -- Intentionally skip callbacks to avoid infinite loops
  def recalculate_balance!
    update_column(:balance, entries.sum(:amount))
  end
  # rubocop:enable Rails/SkipsModelValidations

  private

  def create_initial_entry
    entries.create!(lease: lease, amount: signed_amount, transaction_id: nil)
    recalculate_balance!
  end

  def auto_settle
    SettlementService.auto_settle(self)
  end
end
