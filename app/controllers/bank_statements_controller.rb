# frozen_string_literal: true

class BankStatementsController < ApplicationController
  def index
    authorize BankStatement
    @bank_statements = policy_scope(BankStatement).order(uploaded_at: :desc).page(params[:page]).per(50)
  end

  def show
    @bank_statement = BankStatement.find(params.expect(:id))
    authorize @bank_statement
    @transactions = @bank_statement.bank_transactions
                                   .includes(matched_payment: { lease: :tenant })
                                   .order(date: :desc, id: :desc)
                                   .page(params[:page]).per(50)
    @counts = @bank_statement.bank_transactions.group(:status).count
  end

  def new
    @bank_statement = BankStatement.new
    authorize @bank_statement
  end

  def create
    @bank_statement = BankStatement.new
    authorize @bank_statement
    upload = params.dig(:bank_statement, :file)
    return render_form_error(t(".no_file")) unless upload.respond_to?(:read)

    redirect_to import_and_match(upload), notice: t(".success")
  rescue BankStatementParser::Error => e
    render_form_error(e.message)
  end

  private

  # Parsing comes first so a bad file saves nothing; matching runs once the
  # import has committed.
  def import_and_match(upload)
    statement = import(upload, BankStatementParser.new(upload.read).rows)
    ReconciliationMatcher.new(statement).call
    statement
  end

  def import(upload, rows)
    BankStatement.transaction do
      statement = BankStatement.new(filename: upload.original_filename, uploaded_at: Time.current, status: :processed)
      statement.save!
      rows.each { |row| statement.bank_transactions.create!(row.to_h) }
      statement
    end
  end

  def render_form_error(message)
    @bank_statement ||= BankStatement.new
    @error = message
    render :new, status: :unprocessable_content
  end
end
