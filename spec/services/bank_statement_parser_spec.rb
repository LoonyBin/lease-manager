# frozen_string_literal: true

require "rails_helper"

RSpec.describe BankStatementParser do
  def parse(body) = described_class.new(body).rows

  def error_message(body)
    parse(body)
  rescue described_class::Error => e
    e.message
  end

  def csv(*rows, header: "date,amount,description,reference") = ([header] + rows).join("\n")

  it "reads rows with the documented columns" do
    row = parse(csv("2026-03-10,1500.50,Rent March,UTR1")).first
    expect(row.to_h).to eq(date: Date.new(2026, 3, 10), amount: BigDecimal("1500.50"),
                           description: "Rent March", reference: "UTR1")
  end

  it "accepts the narration, ref and utr aliases and ignores header case" do
    row = parse(csv("2026-03-10,10,Rent,U1", header: "Date,Amount,Narration,UTR")).first
    expect([row.description, row.reference]).to eq(%w[Rent U1])
  end

  it "skips fully blank rows" do
    expect(parse(csv("2026-03-10,10,a,b", ",,,"))).to have_attributes(size: 1)
  end

  {
    "Rs. 1,000.00" => "1000.00", "₹1,000" => "1000", "INR 2500.5" => "2500.5",
    "-50.00" => "-50.00", "-Rs. 1,250.25" => "-1250.25", "1000" => "1000"
  }.each do |text, expected|
    it "reads the amount #{text.inspect} as exactly #{expected}" do
      expect(parse(csv("2026-03-10,\"#{text}\",x,y")).first.amount).to eq(BigDecimal(expected))
    end
  end

  ["1,000.00 Dr", "(500.00)", "50.00-", "", "0", "0.00", "1.2.3", "1.234", "abc", "100000000.00"].each do |text|
    it "refuses the amount #{text.inspect}, naming the row" do
      expect { parse(csv("2026-03-10,10,a,b", "2026-03-11,\"#{text}\",x,y")) }
        .to raise_error(described_class::Error, /Row 3/)
    end
  end

  %w[2026-03-10 10/03/2026 10-03-2026].each do |text|
    it "reads the date #{text} as 10 March 2026" do
      expect(parse(csv("#{text},10,x,y")).first.date).to eq(Date.new(2026, 3, 10))
    end
  end

  %w[12 Mar 2026-13-01 31/02/2026 2026/03/10].push("").each do |text|
    it "refuses the date #{text.inspect}" do
      expect { parse(csv("#{text},10,x,y")) }.to raise_error(described_class::Error, /Row 2.*date/)
    end
  end

  it "refuses a file missing a required header" do
    expect { parse("date,description\n2026-03-10,x") }.to raise_error(described_class::Error, /amount column/)
  end

  {
    "2026-03-11,\"Rs. 9,87x,654.00\",x,y" => "9,87x",
    "99/99/9999,10,x,y" => "99/99/9999",
    "2026-03-11,\"123456789012345.00\",x,y" => "123456789012345"
  }.each do |bad_line, secret|
    it "names the row but not the value #{secret} when it refuses a cell", :aggregate_failures do
      message = error_message(csv("2026-03-10,10,a,b", bad_line))
      expect(message).to include("Row 3")
      expect(message).not_to include(secret)
    end
  end

  it "does not forward the CSV library's message for malformed input" do
    expect(error_message("date,amount\n\"2026-03-10,SECRET-NAME")).not_to include("SECRET-NAME")
  end

  it "refuses malformed CSV" do
    expect { parse("date,amount\n\"2026-03-10,10") }.to raise_error(described_class::Error, /not valid CSV/)
  end

  it "refuses an empty file and invalid UTF-8", :aggregate_failures do
    expect { parse("date,amount") }.to raise_error(described_class::Error, /no rows/)
    expect { parse("date,amount\n2026-03-10,\xFF") }.to raise_error(described_class::Error, /UTF-8/)
  end

  it "strips a byte-order mark and keeps non-ASCII text" do
    row = parse("﻿#{csv('2026-03-10,10,Kiraya ₹ — किराया,y')}".b).first
    expect(row.description).to eq("Kiraya ₹ — किराया")
  end

  it "refuses files over the size and row limits", :aggregate_failures do
    stub_const("#{described_class}::MAX_ROWS", 1)
    expect { parse(csv("2026-03-10,1,a,b", "2026-03-11,1,a,b")) }.to raise_error(described_class::Error, /more than/)
    stub_const("#{described_class}::MAX_BYTES", 10)
    expect { parse(csv("2026-03-10,1,a,b")) }.to raise_error(described_class::Error, /larger than/)
  end

  it "stops reading at the row limit instead of parsing the whole file", :aggregate_failures do
    stub_const("#{described_class}::MAX_ROWS", 3)
    allow(CSV::Row).to receive(:new).and_call_original

    expect { parse("date,amount\n#{"\n" * 50}") }.to raise_error(described_class::Error, /more than/)
    expect(CSV::Row).to have_received(:new).at_most(4).times
  end

  it "judges size from a reported byte count, so nothing need be read", :aggregate_failures do
    stub_const("#{described_class}::MAX_BYTES", 10)
    expect { described_class.check_size!(11) }.to raise_error(described_class::Error, /larger than/)
    expect { described_class.check_size!(10) }.not_to raise_error
  end
end
