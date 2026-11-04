# frozen_string_literal: true

# One line of an uploaded bank statement. Reconciliation only records that a
# line and a payment belong together; it never changes the payment or ledger.
#
# Every transition below is guarded by the state it starts from and returns
# false (changing nothing) when the line is not in an allowed state, so a stale
# page or a double click cannot move a line somewhere it should not go.
class BankTransaction < ApplicationRecord
  LINKED_STATUSES = %w[matched confirmed].freeze

  # Statement text can describe activity unrelated to rent, so it never enters
  # the audit trail's object/object_changes.
  self.paper_trail_options = paper_trail_options.merge(skip: %w[date amount description reference])

  belongs_to :bank_statement
  belongs_to :matched_payment, class_name: "Payment", optional: true

  enum :status, { unmatched: 0, matched: 1, confirmed: 2, rejected: 3, ambiguous: 4 }

  validates :date, presence: true
  validates :amount, presence: true, numericality: { other_than: 0 }
  validate :link_agrees_with_status

  scope :linked, -> { where(status: LINKED_STATUSES) }

  # Ids of payments held by an active line other than +transaction+.
  def self.held_elsewhere(transaction)
    linked.where.not(id: transaction.id).select(:matched_payment_id)
  end

  # A payment changed or is going away: any line linked to it that the payment
  # no longer qualifies for goes back to unmatched, so nothing keeps pointing at
  # a payment that has stopped being a valid match. Runs in the payment's own
  # transaction, which already holds the payment row lock, so the order is
  # payment then line. Each line is re-read under its lock: an admin may have
  # rejected it or re-matched it to another payment since it was listed, and
  # that decision must not be overwritten.
  def self.release_links_for(payment, only_unqualified: true)
    linked.where(matched_payment_id: payment.id).pluck(:id).each do |id|
      line = lock.find_by(id: id)
      next unless line&.linked_to?(payment)
      next if only_unqualified && ReconciliationMatcher.qualifies?(line, payment)

      line.update!(status: :unmatched, matched_payment: nil)
    end
  end

  def linked_to?(payment)
    LINKED_STATUSES.include?(status) && matched_payment_id == payment.id
  end

  def confirm!
    transition(from: %w[matched]) do
      return false unless ReconciliationMatcher.qualifies?(self, matched_payment)

      update!(status: :confirmed)
    end
  end

  def reject!
    transition(from: %w[matched ambiguous confirmed]) do
      update!(status: :rejected, matched_payment: nil)
    end
  end

  # The reset commits (releasing the line lock) before matching starts, because
  # linking must take the payment lock first; see #link!.
  def rematch!
    reset = transition(from: %w[unmatched ambiguous rejected]) do
      update!(status: :unmatched, matched_payment: nil)
    end
    ReconciliationMatcher.match_line(self) if reset
    reset
  end

  # A person picks one of an ambiguous line's current candidates.
  def choose!(payment)
    return false unless payment

    link!(payment, :confirmed, from: %w[ambiguous])
  end

  # Links the line to +payment+ only if the payment still qualifies. The
  # payment row is locked first, so a concurrent edit either commits before the
  # check (and is seen by it) or waits until the link exists (and then releases
  # it through Payment's own callback). Returns false and changes nothing when
  # the payment no longer qualifies, another line already holds it, or this line
  # is no longer in one of the +from+ states.
  #
  # Lock order is always payment, then line: a payment edit holds the payment
  # lock and its callback then updates the line. Taking the line first here
  # could deadlock against that, so the line lock (and its state guard) comes
  # only after the payment lock.
  def link!(payment, new_status, from: %w[unmatched])
    transaction do
      locked = Payment.lock.find_by(id: payment.id)
      next false unless locked

      lock!
      next false unless from.include?(status) && ReconciliationMatcher.qualifies?(self, locked)

      update!(status: new_status, matched_payment: locked)
      true
    end
  rescue ActiveRecord::RecordNotUnique
    false
  end

  # Only an unmatched line can become ambiguous, checked against the locked
  # current row: the matcher holds a stale object, and by the time it writes, a
  # concurrent request may have confirmed, rejected or already linked the line.
  def mark_ambiguous!
    transition(from: %w[unmatched]) { update!(status: :ambiguous) }
  end

  private

  def transition(from:)
    with_lock do
      return false unless from.include?(status)

      yield
      true
    end
  end

  def link_agrees_with_status
    linked = LINKED_STATUSES.include?(status)
    errors.add(:matched_payment, :blank) if linked && matched_payment.nil?
    errors.add(:matched_payment, :present) if !linked && matched_payment
  end
end
