# frozen_string_literal: true

# Process integration tests assert complete CLI transactions.
# rubocop:disable RSpec/DescribeClass, RSpec/MultipleExpectations, RSpec/ExampleLength, Metrics/MethodLength, Layout/LineLength

require "spec_helper"
require "tmpdir"
require "json"
require "open3"

RSpec.describe "uptime notifier" do
  def alert(run: 9, notified: Time.now.to_i, author: "github-actions[bot]", **extra)
    { number: 4, user: { login: author },
      body: "Alert\n<!-- uptime-last-failed-run: #{run} -->\n<!-- uptime-last-notified-at: #{notified} -->" }.merge(extra)
  end

  def invoke(result: "failure", drill: false, real: [], drills: [], error: false)
    Dir.mktmpdir do |dir|
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
      env = { "BASH_ENV" => nil, "ENV" => nil, "PATH" => "#{dir}:#{ENV.fetch('PATH')}", "CALLS" => "#{dir}/calls",
              "REAL" => JSON.generate(real), "DRILLS" => JSON.generate(drills), "ERROR" => error.to_s,
              "GH_REPO" => "owner/repo", "CHECK_RESULT" => result, "IS_DRILL" => drill.to_s,
              "RUN_NUMBER" => "10", "RUN_URL" => "https://github.com/owner/repo/actions/runs/10", "RECIPIENT" => "TMaYaD" }
      _, _, status = Open3.capture3(env, "bin/uptime-notify")
      calls = File.exist?("#{dir}/calls") ? File.readlines("#{dir}/calls").map { |line| JSON.parse(line) } : []
      [status, calls]
    end
  end

  ["failure", "cancelled", "skipped", ""].each do |result|
    it "creates one assigned alert for #{result.inspect}" do
      status, calls = invoke(result: result)
      expect(status).to be_success
      creates = calls.select { |call| call[0, 2] == %w[issue create] }
      expect(creates.size).to eq(1)
      expect(creates.first).to include("production-down", "--assignee", "TMaYaD")
      body = creates.first[creates.first.index("--body") + 1]
      expect(body).to match(%r{\A@TMaYaD Lease Manager public checks failed at [0-9T:+.-]+\.\n\nInspect the \[workflow run\]\(https://github.com/owner/repo/actions/runs/10\) for details\.\n<!-- uptime-last-failed-run: 10 -->\n<!-- uptime-last-notified-at: \d+ -->\z})
    end
  end

  it "deduplicates without lowering the failure marker" do
    _, calls = invoke(real: [alert(run: 12)])
    expect(calls.flatten).not_to include("create", "comment")
    expect(calls.join).to include("uptime-last-failed-run: 12")
  end

  it "mentions again after twelve hours" do
    _, calls = invoke(real: [alert(notified: Time.now.to_i - 43_201)])
    expect(calls.count { |c| c[0, 2] == %w[issue comment] }).to eq(1)
  end

  it "recovers both real and drill alerts" do
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

  it "isolates a failing drill from real alerts" do
    _, calls = invoke(drill: true, real: [alert])
    expect(calls.flatten).to include("uptime-drill", "DRILL: Lease Manager public checks failed")
    expect(calls.flatten).not_to include("PATCH", "comment", "--slurp")
  end

  it "does not let a drill hide a real outage" do
    _, calls = invoke(drills: [alert])
    expect(calls.flatten).to include("production-down", "create")
  end

  it "rejects a healthy drill without writes" do
    status, calls = invoke(result: "success", drill: true)
    expect(status).not_to be_success
    expect(calls).to be_empty
  end

  %w[failure success].each do |result|
    it "ignores spoofed issues and pull requests on #{result}" do
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

# rubocop:enable RSpec/DescribeClass, RSpec/MultipleExpectations, RSpec/ExampleLength, Metrics/MethodLength, Layout/LineLength
