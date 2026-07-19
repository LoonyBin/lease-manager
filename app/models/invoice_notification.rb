# frozen_string_literal: true

# A single scheduled reminder send. This is both the approval queue and the
# audit log: the scheduler materialises rows as +pending+ with the rendered
# message snapshotted, an admin approves them, and delivery stamps the
# outcome onto the same row.
class InvoiceNotification < ApplicationRecord
  MAX_ERROR_LENGTH = 1000 # not configurable: keeps a runaway backtrace out of the audit row

  belongs_to :invoice
  belongs_to :reminder_step, optional: true

  enum :channel, { email: 0 }, default: :email, validate: true
  # `sending` is the in-flight claim a worker takes before dispatching, so two
  # workers racing on the same row cannot both send it.
  enum :status, { pending: 0, approved: 1, sent: 2, failed: 3, cancelled: 4, sending: 5 },
       default: :pending, validate: true

  validates :occurrence_on, presence: true
  validates :recipient_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :subject, presence: true
  validates :body, presence: true

  scope :queued, -> { where(status: %i[pending approved]) }
  scope :recent_first, -> { order(occurrence_on: :desc, id: :desc) }

  def recipient_email=(value)
    super(value.to_s.strip.downcase.presence)
  end

  def approvable?
    pending?
  end

  def cancellable?
    pending? || failed?
  end

  def retryable?
    failed?
  end

  # Re-checked at dispatch time, not just at queue time: an invoice settled or
  # a lease archived/opted out between approval and send drops the row rather
  # than chasing. Chasing a paid invoice is worse than sending nothing.
  def deliverable?
    approved? && invoice.unsettled? && invoice.lease.reminding?
  end

  # Atomically moves this row from +approved+ to +sending+, returning false if
  # another worker (or an admin cancelling) got there first. The conditional
  # UPDATE is the claim: only the caller whose write matched a row proceeds.
  # rubocop:disable Naming/PredicateMethod -- reports whether this caller won the claim
  def claim_for_delivery!
    # rubocop:disable Rails/SkipsModelValidations -- the conditional UPDATE is the lock
    claimed = self.class.where(id: id, status: self.class.statuses[:approved])
                  .update_all(status: self.class.statuses[:sending], updated_at: Time.current)
    # rubocop:enable Rails/SkipsModelValidations
    return false unless claimed == 1

    reload
    true
  end
  # rubocop:enable Naming/PredicateMethod

  def mark_sent!
    update!(status: :sent, sent_at: Time.current, last_error: nil)
  end

  def mark_failed!(error)
    update!(status: :failed, last_error: error.to_s.truncate(MAX_ERROR_LENGTH))
  end

  def to_s
    "#{subject} → #{recipient_email}"
  end
end
