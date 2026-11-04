# frozen_string_literal: true

# Proposes which payment each bank line belongs to. A proposal is never a
# decision: a line is linked only when exactly one payment qualifies and no
# other line is also looking for it, and a person still confirms it. Two or
# more candidates are never resolved by the system; the line becomes ambiguous.
class ReconciliationMatcher
  EXCLUDED_MODES = %w[cash tax_deducted_at_source].freeze
  WINDOW_DAYS = 3

  Candidate = Struct.new(:payment, :basis)

  def self.match_line(transaction)
    new([transaction]).call
  end

  # Payments this line could belong to, each with the reason it qualifies
  # (:reference or :date_amount). Payments held by another active line are left out.
  def self.candidates(transaction)
    eligible_payments(transaction).filter_map do |payment|
      basis = basis_for(transaction, payment)
      Candidate.new(payment, basis) if basis
    end
  end

  def self.eligible_payments(transaction)
    Payment.confirmed_or_later.where(payment_type: direction(transaction), amount: transaction.amount.abs)
           .where(date: window(transaction)).where.not(mode: EXCLUDED_MODES)
           .where.not(id: BankTransaction.held_elsewhere(transaction)).order(:id)
  end

  # A bank credit is a receipt; a bank debit is a refund.
  def self.direction(transaction) = transaction.amount.negative? ? :refund : :payment

  def self.window(transaction) = (transaction.date - WINDOW_DAYS)..(transaction.date + WINDOW_DAYS)
  private_class_method :direction, :window
  private_class_method :eligible_payments

  def self.qualifies?(transaction, payment)
    candidates(transaction).any? { |candidate| candidate.payment == payment }
  end

  def self.basis_for(transaction, payment)
    reference = payment.reference_number.to_s.strip
    return :date_amount if reference.blank?
    return :reference if contains_reference?(transaction.reference, reference)

    if transaction.reference.present?
      :reference if contains_reference?(transaction.description, reference)
    else
      contains_reference?(transaction.description, reference) ? :reference : :date_amount
    end
  end

  # Whole-value, case-insensitive: "123" must not be found inside "UTR991234".
  def self.contains_reference?(text, reference)
    /(?<![[:alnum:]])#{Regexp.escape(reference)}(?![[:alnum:]])/i.match?(text.to_s)
  end

  def initialize(source)
    @lines = source.is_a?(BankStatement) ? source.bank_transactions.unmatched.order(:id).to_a : Array(source)
  end

  def call
    found = @lines.index_with { |line| self.class.candidates(line) }
    reference_sets = found.transform_values { |list| list.select { |c| c.basis == :reference } }
                          .reject { |_, list| list.empty? }
    decide(reference_sets)
    decide(date_amount_sets(found, reference_sets))
  end

  private

  # exactly one candidate that no other line in the group also wants -> proposal
  def decide(sets)
    wanted = sets.values.flatten.map(&:payment).tally
    sets.each do |line, found|
      if found.one? && wanted[found.first.payment] == 1
        propose(line, found.first.payment)
      elsif found.any?
        line.update!(status: :ambiguous)
      end
    end
  end

  # Lines with no reference-confirmed candidate compete on date and amount, but
  # only for payments no reference-seeking line is also after.
  def date_amount_sets(found, reference_sets)
    sought = reference_sets.values.flatten.map(&:payment)
    (found.keys - reference_sets.keys).index_with { |line| found[line].reject { |c| sought.include?(c.payment) } }
  end

  def propose(line, payment)
    line.link!(payment, :matched)
  end
end
