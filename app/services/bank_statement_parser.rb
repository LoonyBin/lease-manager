# frozen_string_literal: true

require "csv"

class BankStatementParser
  def initialize(bank_statement)
    @bank_statement = bank_statement
  end

  def call
    return unless @bank_statement.file.attached?

    parse_csv
    @bank_statement.processed!
  end

  private

  def parse_csv
    csv_content = @bank_statement.file.download
    CSV.parse(csv_content, headers: true, header_converters: :symbol) do |row|
      create_transaction(row)
    end
  end

  def create_transaction(row)
    @bank_statement.bank_transactions.create!(
      date: parse_date(row[:date]),
      amount: row[:amount].to_s.gsub(/[^0-9.-]/, "").to_d,
      description: row[:description] || row[:narration],
      reference: row[:reference] || row[:ref] || row[:utr]
    )
  end

  def parse_date(date_string)
    Date.parse(date_string.to_s)
  rescue ArgumentError
    nil
  end
end
