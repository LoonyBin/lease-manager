# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "json"
require "open3"

# The subject is an executable script, with no Ruby class to describe.
RSpec.describe "alert notifier" do # rubocop:disable RSpec/DescribeClass
  def alert(run: 9, notified: Time.now.to_i, author: "github-actions[bot]", prefix: "uptime", **extra)
    attempt = extra.delete(:attempt)
    body = "Alert\n<!-- #{prefix}-last-failed-run: #{run} -->\n"
    body += "<!-- #{prefix}-last-failed-attempt: #{attempt} -->\n" if attempt
    body += "<!-- #{prefix}-last-notified-at: #{notified} -->"
    { number: 4, user: { login: author }, body: body }.merge(extra)
  end

  def fake_gh(dir)
    File.write("#{dir}/gh", <<~RUBY)
      #!/usr/bin/env ruby
      require "json"
      File.open(ENV.fetch("CALLS"), "a") { |f| f.puts(JSON.generate(ARGV)) }
      exit 1 if ENV["ERROR"] == "true"
      if ARGV.first == "api" && ARGV.include?("--slurp")
        label = ARGV[1][/labels=([^&]+)/, 1]
        puts JSON.generate([JSON.parse(ENV.fetch("FIXTURES")).fetch(label, [])])
      end
    RUBY
    File.chmod(0o755, "#{dir}/gh")
  end

  def sha
    "0123456789abcdef0123456789abcdef01234567"
  end

  def labels(kind)
    { "uptime" => %w[production-down uptime-drill], "deploy" => %w[deploy-failed deploy-drill] }.fetch(kind, [])
  end

  def notifier_env(dir, **options)
    real_label, drill_label = labels(options.fetch(:kind))
    fixtures = { real_label => options.fetch(:real), drill_label => options.fetch(:drills) }
    { "BASH_ENV" => nil, "ENV" => nil, "PATH" => "#{dir}:#{ENV.fetch('PATH')}", "CALLS" => "#{dir}/calls",
      "FIXTURES" => JSON.generate(fixtures), "ERROR" => options.fetch(:error).to_s,
      "ALERT_KIND" => options.fetch(:kind), "COMMIT_SHA" => options.fetch(:sha),
      "RUN_ATTEMPT" => options.fetch(:attempt),
      "GH_REPO" => "owner/repo", "CHECK_RESULT" => options.fetch(:result), "IS_DRILL" => options.fetch(:drill).to_s,
      "RUN_NUMBER" => "10", "RUN_URL" => "https://github.com/owner/repo/actions/runs/10", "RECIPIENT" => "TMaYaD" }
  end

  def invoke(**overrides)
    options = { result: "failure", drill: false, real: [], drills: [], error: false,
                kind: "uptime", sha: sha, attempt: "1" }.merge(overrides)
    Dir.mktmpdir do |dir|
      fake_gh(dir)
      env = notifier_env(dir, **options)
      _, _, status = Open3.capture3(env, "bin/alert-notify")
      calls = File.exist?("#{dir}/calls") ? File.readlines("#{dir}/calls").map { |line| JSON.parse(line) } : []
      [status, calls]
    end
  end

  def failure_body_pattern
    parts = [
      /\A@TMaYaD Lease Manager public checks failed at [0-9T:+.-]+\.\n\n/,
      %r{Inspect the \[workflow run\]\(https://github.com/owner/repo/actions/runs/10\) for details\.\n},
      /<!-- uptime-last-failed-run: 10 -->\n<!-- uptime-last-failed-attempt: 1 -->\n/,
      /<!-- uptime-last-notified-at: \d+ -->\z/
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

  context "with the deploy kind" do
    def deploy_alert(**extra)
      alert(prefix: "deploy", **extra)
    end

    def deploy(**)
      invoke(kind: "deploy", **)
    end

    def creates(calls)
      calls.select { |call| call[0, 2] == %w[issue create] }
    end

    def body_of(call)
      call[call.index("--body") + 1]
    end

    context "when a deploy fails with no alert open" do
      let(:transaction) { deploy }
      let(:created) { creates(transaction.last) }

      it "succeeds and opens exactly one alert", :aggregate_failures do
        expect(transaction.first).to be_success
        expect(created.size).to eq(1)
      end

      it "labels and assigns the alert" do
        expect(created.first).to include("deploy-failed", "--assignee", "TMaYaD", "Lease Manager deploy failed")
      end

      it "links the run and the commit" do
        expect(body_of(created.first)).to include("https://github.com/owner/repo/actions/runs/10",
                                                  "https://github.com/owner/repo/commit/#{sha}", "[0123456](")
      end
    end

    it "uses only fixed text and metadata" do
      _, calls = deploy
      pattern = /\A@TMaYaD Lease Manager deploy failed at [0-9T:+.-]+\. .*\n\nLatest failed deploy: .*\n/m
      expect(body_of(creates(calls).first)).to match(pattern).and include("<!-- deploy-last-failed-run: 10 -->\n")
    end

    ["cancelled", "skipped", ""].each do |result|
      it "stays silent for result #{result.inspect}", :aggregate_failures do
        status, calls = deploy(result: result)
        expect(status).to be_success
        expect(calls).to be_empty
      end
    end

    context "when a deploy alert is already open" do
      let(:old) do
        deploy_alert(run: 8).merge(body: "Latest failed deploy: [run](https://example.test/old)\n" \
                                         "<!-- deploy-last-failed-run: 8 -->\n" \
                                         "<!-- deploy-last-notified-at: #{Time.now.to_i} -->")
      end
      let(:calls) { deploy(real: [old]).last }

      it "does not open a second alert or comment" do
        expect(calls.flatten).not_to include("comment", "create")
      end

      it "records the latest run and commit" do
        expect(calls.join).to include("deploy-last-failed-run: 10", "actions/runs/10", "commit/#{sha}")
      end

      it "replaces the previous run link" do
        expect(calls.join).not_to include("example.test/old")
      end
    end

    it "mentions again after twelve hours" do
      _, calls = deploy(real: [deploy_alert(notified: Time.now.to_i - 43_201)])
      expect(calls.count { |c| c[0, 2] == %w[issue comment] }).to eq(1)
    end

    it "recovers real and drill deploy alerts without touching uptime labels", :aggregate_failures do
      _, calls = deploy(result: "success", real: [deploy_alert], drills: [deploy_alert(number: 5)])
      expect(calls.count { |c| c.include?("state=closed") }).to eq(2)
      expect(calls.count { |c| c[0, 2] == %w[issue comment] }).to eq(2)
      expect(calls.join).not_to include("production-down", "uptime-drill")
    end

    it "does not let uptime recovery query deploy labels" do
      _, calls = invoke(result: "success")
      expect(calls.join).not_to include("deploy-failed", "deploy-drill")
    end

    it "closes an alert when a re-run of the same run number succeeds" do
      _, calls = deploy(result: "success", attempt: "2", real: [deploy_alert(run: 10, attempt: 1)])
      expect(calls.flatten).to include("state=closed")
    end

    it "does not close an alert on an older attempt" do
      _, calls = deploy(result: "success", attempt: "1", real: [deploy_alert(run: 10, attempt: 2)])
      expect(calls.flatten).not_to include("PATCH", "comment")
    end

    [nil, "", "main", "ABCDEF0123456789ABCDEF0123456789ABCDEF01", "0123456"].each do |sha|
      it "refuses commit #{sha.inspect} without writes", :aggregate_failures do
        status, calls = deploy(sha: sha)
        expect(status).not_to be_success
        expect(calls).to be_empty
      end
    end

    it "opens a drill alert without touching real alerts", :aggregate_failures do
      _, calls = deploy(drill: true, real: [deploy_alert])
      expect(calls.flatten).to include("deploy-drill", "DRILL: Lease Manager deploy failed")
      expect(calls.flatten).not_to include("PATCH", "comment", "--slurp")
    end

    it "rejects a healthy drill without writes", :aggregate_failures do
      status, calls = deploy(result: "success", drill: true)
      expect(status).not_to be_success
      expect(calls).to be_empty
    end

    %w[failure success].each do |result|
      it "ignores spoofed issues and pull requests on #{result}", :aggregate_failures do
        _, calls = deploy(result: result, real: [deploy_alert(author: "someone"), deploy_alert(pull_request: {})])
        expect(calls.flatten).not_to include("PATCH", "comment")
        expect(calls.flatten.include?("create")).to eq(result == "failure")
      end
    end
  end

  [nil, "", "other"].each do |kind|
    it "refuses ALERT_KIND #{kind.inspect} without writes", :aggregate_failures do
      status, calls = invoke(kind: kind)
      expect(status).not_to be_success
      expect(calls).to be_empty
    end
  end

  it "keeps recovering an uptime alert when its failed run is older", :aggregate_failures do
    _, calls = invoke(result: "success", real: [alert(run: 9, attempt: 3)])
    expect(calls.flatten).to include("state=closed")
  end
end
