# frozen_string_literal: true

# One line of an uploaded bank statement. Reconciliation only records that a
# line and a payment belong together; it never changes the payment or ledger.
#
# Every transition below is guarded by the state it starts from and returns
# false (changing nothing) when the line is not in an allowed state, so a stale
# page or a double click cannot move a line somewhere it should not go.
class BankTransaction < ApplicationRecord
  LINKED_STATUSES = %w[matched confirmed].freeze

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
  # transaction.
  def self.release_links_for(payment, only_unqualified: true)
    linked.where(matched_payment_id: payment.id).find_each do |line|
      next if only_unqualified && ReconciliationMatcher.qualifies?(line, payment)

      line.update!(status: :unmatched, matched_payment: nil)
    end
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

  def rematch!
    transition(from: %w[unmatched ambiguous rejected]) do
      update!(status: :unmatched, matched_payment: nil)
      ReconciliationMatcher.match_line(self)
    end
  end

  # A person picks one of an ambiguous line's current candidates.
  def choose!(payment)
    transition(from: %w[ambiguous]) do
      return false unless payment && ReconciliationMatcher.candidates(self).any? { |c| c.payment == payment }

      update!(status: :confirmed, matched_payment: payment)
    rescue ActiveRecord::RecordNotUnique
      false
    end
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
