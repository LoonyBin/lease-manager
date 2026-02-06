# frozen_string_literal: true

class Invoice < ApplicationRecord
  belongs_to :lease
  has_many :line_items, dependent: :destroy
  accepts_nested_attributes_for :line_items, allow_destroy: true
  has_many :entries, as: :instrument, dependent: :destroy

  ransacker :total_amount do
    Arel.sql("(SELECT COALESCE(SUM(line_items.amount), 0) FROM line_items WHERE line_items.invoice_id = invoices.id)")
  end

  enum :status, { draft: 0, finalized: 1, sent: 2, paid: 3, cancelled: 4, partially_paid: 5 }, default: :draft,
                                                                                               validate: true
  enum :document_type, { invoice: 0, credit_note: 1 }, default: :invoice

  validates :date, presence: true
  validates :status, presence: true

  before_save :assign_number, if: -> { finalized? && number.nil? }
  after_save :create_initial_entry, if: :should_create_entry?
  after_save :auto_settle, if: :should_auto_settle?

  scope :finalized_or_later, -> { where(status: %i[finalized sent paid partially_paid]) }
  scope :rental, -> { joins(:line_items).where(line_items: { category: "rent" }).distinct }

  def total_amount
    line_items.sum(:amount)
  end

  def paid_amount
    return 0 unless total_amount.positive?

    [total_amount - balance, 0].max
  end

  def outstanding_amount
    balance
  end

  def credit?
    credit_note?
  end

  def debit?
    invoice?
  end

  def signed_amount
    debit? ? total_amount : -total_amount
  end

  # rubocop:disable Rails/SkipsModelValidations -- Intentionally skip callbacks to avoid infinite loops
  def recalculate_balance!
    update_column(:balance, entries.sum(:amount))
    update_status_from_balance!
  end

  def update_status_from_balance!
    return if draft? || cancelled?

    if balance <= 0 && total_amount.positive?
      update_column(:status, self.class.statuses[:paid])
    elsif balance < total_amount
      update_column(:status, self.class.statuses[:partially_paid])
    end
  end
  # rubocop:enable Rails/SkipsModelValidations

  private

  def assign_number
    InvoiceNumberingService.new(self).call
  end

  def should_create_entry?
    finalized_or_later? && entries.initial.none? && !signed_amount.zero?
  end

  def should_auto_settle?
    saved_change_to_status? && finalized_or_later? && balance != 0
  end

  def finalized_or_later?
    finalized? || sent? || paid? || partially_paid?
  end

  def create_initial_entry
    entries.create!(lease: lease, amount: signed_amount, transaction_id: nil)
    recalculate_balance!
  end

  def auto_settle
    SettlementService.auto_settle(self)
  end
end
