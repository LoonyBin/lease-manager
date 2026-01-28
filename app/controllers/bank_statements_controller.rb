# frozen_string_literal: true

class BankStatementsController < ApplicationController
  def index
    @bank_statements = BankStatement.order(uploaded_at: :desc)
  end

  def show
    @bank_statement = BankStatement.find(params[:id])
    @transactions = @bank_statement.bank_transactions.includes(:matched_payment)
  end

  def new
    @bank_statement = BankStatement.new
  end

  def create
    @bank_statement = BankStatement.new(bank_statement_params)
    @bank_statement.uploaded_at = Time.current
    @bank_statement.filename = params[:bank_statement][:file]&.original_filename

    if @bank_statement.save
      process_statement
      redirect_to @bank_statement, notice: t(".success")
    else
      render :new, status: :unprocessable_content
    end
  end

  private

  def process_statement
    BankStatementParser.new(@bank_statement).call
    ReconciliationMatcher.new(@bank_statement).call
  end

  def bank_statement_params
    params.expect(bank_statement: [:file])
  end
end
