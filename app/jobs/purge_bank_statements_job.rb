# frozen_string_literal: true

class PurgeBankStatementsJob < ApplicationJob
  queue_as :default

  def perform
    BankStatementPurger.new.call
  end
end
