# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "json"
require "open3"

# The subject is an executable script, with no Ruby class to describe.
RSpec.describe "uptime notifier" do # rubocop:disable RSpec/DescribeClass
  def alert(run: 9, notified: Time.now.to_i, author: "github-actions[bot]", **extra)
    body = "Alert\n<!-- uptime-last-failed-run: #{run} -->\n" \
           "<!-- uptime-last-notified-at: #{notified} -->"
    { number: 4, user: { login: author }, body: body }.merge(extra)
  end

  def fake_gh(dir)
    File.write("#{dir}/gh", <<~RUBY)
      #!/usr/bin/env ruby
      require "json"
      File.open(ENV.fetch("CALLS"), "a") { |f| f.puts(JSON.generate(ARGV)) }
      exit 1 if ENV["ERROR"] == "true"
      if ARGV.first == "api" && ARGV.include?("--slurp")
        puts JSON.generate([JSON.parse(ENV.fetch(ARGV[1].include?("production-down") ? "REAL" : "DRILLS"))])
      end
    RUBY
    File.chmod(0o755, "#{dir}/gh")
  end

  def notifier_env(dir, **options)
    { "BASH_ENV" => nil, "ENV" => nil, "PATH" => "#{dir}:#{ENV.fetch('PATH')}", "CALLS" => "#{dir}/calls",
      "REAL" => JSON.generate(options.fetch(:real)), "DRILLS" => JSON.generate(options.fetch(:drills)),
      "ERROR" => options.fetch(:error).to_s,
      "GH_REPO" => "owner/repo", "CHECK_RESULT" => options.fetch(:result), "IS_DRILL" => options.fetch(:drill).to_s,
      "RUN_NUMBER" => "10", "RUN_URL" => "https://github.com/owner/repo/actions/runs/10", "RECIPIENT" => "TMaYaD" }
  end

  def invoke(result: "failure", drill: false, real: [], drills: [], error: false)
    Dir.mktmpdir do |dir|
      fake_gh(dir)
      env = notifier_env(dir, result: result, drill: drill, real: real, drills: drills, error: error)
      _, _, status = Open3.capture3(env, "bin/uptime-notify")
      calls = File.exist?("#{dir}/calls") ? File.readlines("#{dir}/calls").map { |line| JSON.parse(line) } : []
      [status, calls]
    end
  end

  def failure_body_pattern
    parts = [
      /\A@TMaYaD Lease Manager public checks failed at [0-9T:+.-]+\.\n\n/,
      %r{Inspect the \[workflow run\]\(https://github.com/owner/repo/actions/runs/10\) for details\.\n},
      /<!-- uptime-last-failed-run: 10 -->\n<!-- uptime-last-notified-at: \d+ -->\z/
    ]
    Regexp.new(parts.map(&:source).join)
  end

  ["failure", "cancelled", "skipped", ""].each do |result|
    context "when the check result is #{result.inspect}" do
      let(:transaction) { invoke(result: result) }
      let(:creates) { transaction.last.select { |call| call[0, 2] == %w[issue create] } }

      it "succeeds" do
        expect(transaction.first).to be_success
      end

      it "creates exactly one alert" do
        expect(creates.size).to eq(1)
      end

      it "assigns and labels the alert" do
        expect(creates.first).to include("production-down", "--assignee", "TMaYaD")
      end

      it "uses only the fixed alert text and run metadata" do
        body = creates.first[creates.first.index("--body") + 1]
        expect(body).to match(failure_body_pattern)
      end
    end
  end

  it "deduplicates without lowering the failure marker", :aggregate_failures do
    _, calls = invoke(real: [alert(run: 12)])
    expect(calls.flatten).not_to include("create", "comment")
    expect(calls.join).to include("uptime-last-failed-run: 12")
  end

  it "mentions again after twelve hours" do
    _, calls = invoke(real: [alert(notified: Time.now.to_i - 43_201)])
    expect(calls.count { |c| c[0, 2] == %w[issue comment] }).to eq(1)
  end

  it "recovers both real and drill alerts", :aggregate_failures do
    _, calls = invoke(result: "success", real: [alert], drills: [alert.merge(number: 5)])
    expect(calls.count { |c| c.include?("state=closed") }).to eq(2)
    expect(calls.count { |c| c[0, 2] == %w[issue comment] }).to eq(2)
  end

  [10, 11].each do |run|
    it "does not close a failure from run #{run}" do
      _, calls = invoke(result: "success", real: [alert(run: run)])
      expect(calls.flatten).not_to include("PATCH", "comment")
    end
  end

  ["", "<!-- uptime-last-failed-run: invalid -->"].each do |body|
    it "recovers an alert with a missing or invalid marker" do
      _, calls = invoke(result: "success", real: [alert.merge(body: body)])
      expect(calls.flatten).to include("state=closed")
    end
  end

  it "makes no writes when healthy without alerts" do
    _, calls = invoke(result: "success")
    expect(calls.all? { |c| c.include?("--slurp") }).to be(true)
  end

  it "isolates a failing drill from real alerts", :aggregate_failures do
    _, calls = invoke(drill: true, real: [alert])
    expect(calls.flatten).to include("uptime-drill", "DRILL: Lease Manager public checks failed")
    expect(calls.flatten).not_to include("PATCH", "comment", "--slurp")
  end

  it "does not let a drill hide a real outage" do
    _, calls = invoke(drills: [alert])
    expect(calls.flatten).to include("production-down", "create")
  end

  it "rejects a healthy drill without writes", :aggregate_failures do
    status, calls = invoke(result: "success", drill: true)
    expect(status).not_to be_success
    expect(calls).to be_empty
  end

  %w[failure success].each do |result|
    it "ignores spoofed issues and pull requests on #{result}", :aggregate_failures do
      _, calls = invoke(result: result, real: [alert(author: "someone"), alert(pull_request: {})])
      expect(calls.flatten).not_to include("PATCH", "comment")
      expect(calls.flatten.include?("create")).to eq(result == "failure")
    end
  end

  it "propagates API errors" do
    status, = invoke(error: true)
    expect(status).not_to be_success
  end
end
