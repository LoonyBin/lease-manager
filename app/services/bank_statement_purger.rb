# frozen_string_literal: true

# Deletes bank statement lines that are not confirmed once their statement was
# uploaded BankStatement::RETENTION_PERIOD ago, then any such statement left
# with no lines. Age counts from the upload, so a line that stops being
# confirmed on an old statement goes at the next run.
class BankStatementPurger
  def call
    # One short transaction per line: a statement-wide one would hold up to
    # MAX_ROWS row locks against an admin working on the same page. There is no
    # rescue: a failure is systemic, so the job should fail visibly and resume.
    BankTransaction.past_retention.pluck(:id).each { |id| BankTransaction.destroy_unless_confirmed(id) }

    # Lines go first so a statement emptied in this run goes in the same run.
    # The where.missing guard is load-bearing: BankStatement destroys its lines,
    # which would take a confirmed line with it.
    BankStatement.past_retention.where.missing(:bank_transactions).find_each(&:destroy!)
  end
end
