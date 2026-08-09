# frozen_string_literal: true

class Payment < ApplicationRecord
  belongs_to :lease
  has_many :entries, as: :instrument, dependent: :destroy
  has_one_attached :attachment

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
  enum :status, { draft: 0, confirmed: 1, rejected: 2, partially_allocated: 3, fully_allocated: 4 },
       default: :confirmed, validate: true

  # Ransack allowlist — keep in sync with app/views/payments/_search.html.haml and _sort.html.haml.
  # created_at is required by payments_controller.rb's default sort ["date desc", "created_at desc"]:
  # without it the tiebreak node is silently dropped and same-date ordering becomes nondeterministic.
  # id serves invoices/show's "View payments" (id_in) link; lease_id serves leases/show's "All
  # payments" link; the lease association carries the lease_tenant_name sort.
  def self.ransackable_attributes(_auth_object = nil)
    %w[id lease_id reference_number date amount payment_type mode created_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[lease]
  end

  after_save :sync_initial_entry, if: :should_sync_entry?
  after_save :auto_settle, if: :should_auto_settle?
  after_save :deallocate, if: :should_deallocate?

  scope :confirmed_or_later, -> { where(status: %i[confirmed partially_allocated fully_allocated]) }
  scope :unsettled, -> { where(status: %i[confirmed partially_allocated]) }

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
    update_status_from_balance!
  end

  def update_status_from_balance!
    return if draft? || rejected?

    new_status = balance.abs.zero? ? :fully_allocated : :partially_allocated
    update_column(:status, self.class.statuses[new_status])
  end
  # rubocop:enable Rails/SkipsModelValidations

  def confirmed_or_later?
    confirmed? || partially_allocated? || fully_allocated?
  end

  def unsettled?
    confirmed? || partially_allocated?
  end

  private

  def should_sync_entry?
    confirmed_or_later? && initial_entry_stale?
  end

  def should_auto_settle?
    saved_change_to_status? && confirmed_or_later? && balance != 0
  end

  # Rejecting an allocated payment must un-do its allocation. The entries.exists?
  # guard keeps this to payments that were actually confirmed and allocated: a
  # draft → rejected flip (or a record born rejected) has no footprint to unwind.
  def should_deallocate?
    saved_change_to_status? && rejected? && entries.exists?
  end

  def initial_entry_stale?
    initial = entries.initial.first
    initial.nil? || initial.amount != signed_amount
  end

  def sync_initial_entry
    entries.initial.first_or_initialize(lease: lease, transaction_id: nil).tap do |entry|
      entry.amount = signed_amount
    end.save!
    recalculate_balance!
  end

  def auto_settle
    return unless unsettled?

    SettlementService.auto_settle(self)
  end

  def deallocate
    SettlementService.deallocate(self)
  end
end
