# frozen_string_literal: true

class Invoice < ApplicationRecord
  include Invoice::Totals

  belongs_to :lease
  belongs_to :invoice_template, optional: true
  has_many :line_items, dependent: :destroy
  accepts_nested_attributes_for :line_items, allow_destroy: true
  has_many :entries, as: :instrument, dependent: :destroy
  has_many :invoice_notifications, dependent: :destroy

  enum :status, { draft: 0, finalized: 1, sent: 2, paid: 3, cancelled: 4, partially_paid: 5 }, default: :draft,
                                                                                               validate: true
  enum :document_type, { invoice: 0, credit_note: 1 }, default: :invoice

  validates :date, presence: true
  validates :status, presence: true
  # Only debit invoices reserve a template's month, and only against other
  # debit invoices (the +covering+ conditions): a credit note may share a
  # (template, date) with the month's real invoice. Matches the partial unique
  # index, which carries the same +document_type = 0+ predicate. See #163.
  validates :date, uniqueness: { scope: :invoice_template_id, conditions: -> { covering } },
                   if: -> { invoice_template_id? && invoice? }
  validate :invoice_template_belongs_to_lease, if: :invoice_template_id?

  # Ransack allowlist — keep in sync with app/views/invoices/_search.html.haml, _sort.html.haml,
  # and invoices_controller.rb's default sort. total_amount is a ransacker (Invoice::Totals), so it
  # must be listed explicitly now that the base default is empty. lease_id serves leases/show's
  # "All invoices" link; the lease association serves lease_tenant_name / lease_property_name.
  # created_at is required by invoices_controller.rb's default sort ["date desc", "created_at desc"]:
  # without it the tiebreak node is silently dropped and same-date ordering becomes nondeterministic.
  def self.ransackable_attributes(_auth_object = nil)
    %w[date number document_type status lease_id total_amount created_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[lease]
  end

  before_validation :set_default_due_date
  before_save :assign_number, if: -> { finalized? && number.nil? }
  after_save :sync_initial_entry, if: :should_sync_entry?
  after_save :auto_settle, if: :should_auto_settle?

  scope :finalized_or_later, -> { where(status: %i[finalized sent paid partially_paid]) }
  scope :unsettled, -> { where(status: %i[finalized sent partially_paid]) }
  scope :overdue,  -> { unsettled.where(due_date: ...Date.current) }
  scope :near_due, -> { unsettled.where(due_date: Date.current..7.days.from_now) }

  # Invoices that count as a month having been billed by a template: any debit
  # invoice, cancelled included (billed then waived is a decision, not a gap);
  # credit notes are corrections, not bills, so they never cover a month.
  # +cancelled+ is a status, not a document_type, so filtering on document_type
  # provably keeps cancelled invoices and excludes credit notes. See #163.
  scope :covering, -> { where(document_type: :invoice) }

  def credit?
    credit_note?
  end

  def debit?
    invoice?
  end

  # rubocop:disable Rails/SkipsModelValidations -- Intentionally skip callbacks to avoid infinite loops
  def recalculate_balance!
    update_column(:balance, entries.sum(:amount))
    update_status_from_balance!
    lease.recalculate_cached_balance!
  end

  def update_status_from_balance!
    return if draft? || cancelled?

    new_status = :finalized
    if balance.zero? && total_amount.positive?
      new_status = :paid
    elsif balance < total_amount
      new_status = :partially_paid
    end

    update_column(:status, self.class.statuses[new_status])
  end
  # rubocop:enable Rails/SkipsModelValidations

  def unsettled?
    finalized? || sent? || partially_paid?
  end

  def overdue?
    unsettled? && due_date.present? && due_date < Date.current
  end

  def near_due?
    unsettled? && due_date.present? && due_date.between?(Date.current, 7.days.from_now)
  end

  private

  # Also rejects dangling template ids (deleted templates), which would
  # otherwise only fail at the database foreign-key constraint.
  def invoice_template_belongs_to_lease
    return if invoice_template&.lease_id == lease_id

    errors.add(:invoice_template, "must belong to the invoice's lease")
  end

  def set_default_due_date
    self.due_date ||= date
  end

  def assign_number
    InvoiceNumberingService.new(self).call
  end

  def should_sync_entry?
    finalized_or_later? && !signed_amount.zero? && initial_entry_stale?
  end

  def should_auto_settle?
    saved_change_to_status? && finalized_or_later? && balance != 0
  end

  def finalized_or_later?
    finalized? || sent? || paid? || partially_paid?
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
end
