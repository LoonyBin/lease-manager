# frozen_string_literal: true

class BankTransactionsController < ApplicationController
  def confirm
    @transaction = BankTransaction.find(params[:id])
    @transaction.confirmed!
    redirect_back_or_to(bank_statement_path(@transaction.bank_statement), notice: t(".success"))
  end

  def reject
    @transaction = BankTransaction.find(params[:id])
    @transaction.update!(matched_payment: nil, status: :rejected)
    redirect_back_or_to(bank_statement_path(@transaction.bank_statement), notice: t(".success"))
  end

  def rematch
    @transaction = BankTransaction.find(params[:id])
    @transaction.update!(matched_payment: nil, status: :unmatched)
    redirect_back_or_to(bank_statement_path(@transaction.bank_statement), notice: t(".success"))
  end
end
