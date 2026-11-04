# frozen_string_literal: true

class BankTransactionsController < ApplicationController
  before_action :set_transaction

  def confirm
    respond_to_transition(@transaction.confirm!, t(".success"))
  end

  def reject
    respond_to_transition(@transaction.reject!, t(".success"))
  end

  def rematch
    respond_to_transition(@transaction.rematch!, t(".success"))
  end

  def choose
    payment = Payment.find_by(id: params[:payment_id])
    respond_to_transition(@transaction.choose!(payment), t(".success"))
  end

  private

  def set_transaction
    @transaction = BankTransaction.find(params.expect(:id))
    authorize @transaction
  end

  def respond_to_transition(done, notice)
    flash_options = done ? { notice: notice } : { alert: t("bank_transactions.not_allowed") }
    redirect_to bank_statement_path(@transaction.bank_statement), **flash_options
  end
end
