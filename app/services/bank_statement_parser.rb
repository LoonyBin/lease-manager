# frozen_string_literal: true

require "csv"

# Reads a bank statement CSV into validated rows. Nothing is saved here: either
# every row is readable and #rows returns them, or Error names the first row
# that is not, so a file never half-imports.
class BankStatementParser
  class Error < StandardError; end

  MAX_BYTES = 5.megabytes
  MAX_ROWS = 5_000
  AMOUNT_FORMAT = /\A-?(?:₹|Rs\.?|INR)?\s*(?:\d{1,3}(?:,\d{3})+|\d+)(?:\.\d{1,2})?\z/i
  DATE_FORMATS = { /\A\d{4}-\d{2}-\d{2}\z/ => "%Y-%m-%d",
                   %r{\A\d{2}/\d{2}/\d{4}\z} => "%d/%m/%Y",
                   /\A\d{2}-\d{2}-\d{4}\z/ => "%d-%m-%Y" }.freeze
  MAX_AMOUNT = BigDecimal("99999999.99")

  Row = Struct.new(:date, :amount, :description, :reference, keyword_init: true)

  def initialize(content)
    @content = content.to_s
  end

  def rows
    raise Error, "The file is larger than #{MAX_BYTES / 1.megabyte} MB." if @content.bytesize > MAX_BYTES

    table = read_table
    check_row_count(table)
    table.each_with_index.reject { |row, _| row.fields.all?(&:blank?) }.map { |row, index| build_row(row, index + 2) }
  end

  private

  def read_table
    table = CSV.parse(utf8_text, headers: true, header_converters: ->(h) { h.to_s.strip.downcase })
    missing = %w[date amount] - table.headers
    raise Error, "The file is missing the #{missing.join(' and ')} column." if missing.any?

    table
  rescue CSV::MalformedCSVError
    raise Error, "The file is not valid CSV."
  end

  def check_row_count(table)
    raise Error, "The file has no rows." if table.empty?
    raise Error, "The file has more than #{MAX_ROWS} rows." if table.size > MAX_ROWS
  end

  def utf8_text
    text = @content.dup.force_encoding(Encoding::UTF_8).delete_prefix("\uFEFF")
    raise Error, "The file is not valid UTF-8 text." unless text.valid_encoding?

    text
  end

  def build_row(row, number)
    Row.new(date: parse_date(row["date"], number),
            amount: parse_amount(row["amount"], number),
            description: (row["description"] || row["narration"]).to_s.strip.presence,
            reference: (row["reference"] || row["ref"] || row["utr"]).to_s.strip.presence)
  end

  def parse_date(value, number)
    text = value.to_s.strip
    format = DATE_FORMATS.find { |pattern, _| pattern.match?(text) }&.last
    Date.strptime(text, format)
  rescue Date::Error, TypeError
    raise Error, "Row #{number}: the date is not readable. Use YYYY-MM-DD or DD/MM/YYYY."
  end

  def parse_amount(value, number)
    text = value.to_s.strip
    raise Error, "Row #{number}: the amount is not readable." unless AMOUNT_FORMAT.match?(text)

    amount = BigDecimal(text.sub(/\A(-?)(?:₹|Rs\.?|INR)?\s*/i, '\\1').delete(","))
    raise Error, "Row #{number}: the amount must not be zero." if amount.zero?
    raise Error, "Row #{number}: the amount is too large." if amount.abs > MAX_AMOUNT

    amount
  end
end
