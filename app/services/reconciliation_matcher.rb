# frozen_string_literal: true

class ReconciliationMatcher
  AMOUNT_TOLERANCE = 0.01

  def initialize(bank_statement)
    @bank_statement = bank_statement
  end

  def call
    @bank_statement.bank_transactions.unmatched.find_each do |transaction|
      match = find_match(transaction)
      transaction.update!(matched_payment: match, status: :matched) if match
    end
  end

  private

  def find_match(transaction)
    Payment
      .where(date: date_range(transaction.date))
      .where(amount: amount_range(transaction.amount.abs))
      .find do |payment|
        reference_matches?(transaction, payment)
      end
  end

  def date_range(date)
    (date - 3.days)..(date + 3.days)
  end

  def amount_range(amount)
    (amount - AMOUNT_TOLERANCE)..(amount + AMOUNT_TOLERANCE)
  end

  def reference_matches?(transaction, payment)
    return true if payment.reference_number.blank?
    return true if transaction.reference.blank?

    transaction.reference.include?(payment.reference_number) ||
      transaction.description&.include?(payment.reference_number)
  end
end
