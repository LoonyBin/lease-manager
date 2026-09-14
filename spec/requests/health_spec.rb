# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Health" do
  describe "GET /health/ready" do
    context "when the database is reachable and migrated" do
      before { get health_ready_path }

      let(:all_green) do
        { "status" => "ok",
          "checks" => { "database" => { "status" => "ok" },
                        "migrations" => { "status" => "ok" },
                        "domain_tables" => { "status" => "ok" } } }
      end

      it "answers 200 without a session, as /up does" do
        expect(response).to have_http_status(:ok)
      end

      it "reports every check green" do
        expect(response.parsed_body).to eq(all_green)
      end
    end

    context "when a migration is pending" do
      before do
        allow(ActiveRecord::Migration).to receive(:check_all_pending!)
          .and_raise(ActiveRecord::PendingMigrationError)
        get health_ready_path
      end

      it "fails with 503" do
        expect(response).to have_http_status(:service_unavailable)
      end

      it "names the check that failed" do
        expect(response.parsed_body.dig("checks", "migrations"))
          .to eq("status" => "error", "error" => "ActiveRecord::PendingMigrationError")
      end
    end

    context "when a domain table cannot be read" do
      before do
        allow(Lease).to receive(:limit).and_raise(ActiveRecord::StatementInvalid, "relation does not exist")
        get health_ready_path
      end

      it "fails with 503" do
        expect(response).to have_http_status(:service_unavailable)
      end
    end

    # The endpoint is public, so the failure detail it hands back has to be safe
    # for anyone to read. An exception message can carry a connection string, a
    # fragment of SQL or a row value; the class name cannot.
    context "when the failure message carries a secret" do
      before do
        allow(ActiveRecord::Migration).to receive(:check_all_pending!)
          .and_raise(ActiveRecord::ConnectionNotEstablished, "postgres://lease:hunter2@db.internal")
        get health_ready_path
      end

      it "reports the exception class" do
        expect(response.body).to include("ActiveRecord::ConnectionNotEstablished")
      end

      it "does not report its message" do
        expect(response.body).not_to include("hunter2")
      end
    end
  end

  describe "GET /health/workers" do
    context "when no worker has registered" do
      before { get health_workers_path }

      it "fails with 503" do
        expect(response).to have_http_status(:service_unavailable)
      end

      it "says why" do
        expect(response.parsed_body).to include("status" => "error", "error" => "no_live_worker", "live_workers" => 0)
      end
    end

    context "with a live worker" do
      before do
        register_worker(name: "worker-old", pid: 101, created_at: 10.minutes.ago)
        register_worker(name: "worker-new", pid: 102, created_at: 30.seconds.ago, last_heartbeat_at: 5.seconds.ago)
        get health_workers_path
      end

      it "answers 200 and counts the live workers", :aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to include("status" => "ok", "live_workers" => 2)
      end

      # started_seconds_ago is what tells a release check whether the worker it
      # can see is this release's or the one it replaced.
      it "reports the newest worker's age and heartbeat" do
        expect(response.parsed_body["newest_worker"]).to include(
          "started_seconds_ago" => be_within(5).of(30), "last_heartbeat_seconds_ago" => be_within(5).of(5)
        )
      end
    end

    # A worker whose heartbeat has stopped has not necessarily removed its row:
    # a process killed outright leaves one behind until something prunes it.
    context "with a worker that has stopped heartbeating" do
      before do
        register_worker(name: "worker-dead", pid: 103, last_heartbeat_at: 1.hour.ago)
        get health_workers_path
      end

      it "does not count it as live", :aggregate_failures do
        expect(response).to have_http_status(:service_unavailable)
        expect(response.parsed_body).to include("error" => "no_live_worker")
      end
    end

    context "with a live process that is not a worker" do
      before do
        register_worker(name: "dispatcher-1", pid: 104, kind: "Dispatcher")
        get health_workers_path
      end

      it "does not count it as a worker" do
        expect(response).to have_http_status(:service_unavailable)
      end
    end

    context "when the queue tables cannot be read" do
      before do
        allow(SolidQueue::Process).to receive(:where).and_raise(ActiveRecord::StatementInvalid, "no such table")
        get health_workers_path
      end

      it "fails with 503 rather than raising", :aggregate_failures do
        expect(response).to have_http_status(:service_unavailable)
        expect(response.parsed_body["error"]).to eq("ActiveRecord::StatementInvalid")
      end
    end
  end

  # config/environments/production.rb exempts these paths from host
  # authorization and from the http-to-https redirect. Checks reach the
  # container directly, so a health route left off the list is answered with a
  # 403 by a machine that is only ever asked questions by machines.
  describe "the health check path list" do
    it "covers every health route and nothing else" do
      expect(Rails.application.config.x.health_check_paths).to match_array(routed_health_paths)
    end

    def routed_health_paths
      Rails.application.routes.routes.filter_map do |route|
        controller = route.defaults[:controller]
        route.path.spec.to_s.chomp("(.:format)") if controller.in?(%w[health rails/health])
      end
    end
  end

  def register_worker(name:, pid:, kind: "Worker", created_at: 1.minute.ago, last_heartbeat_at: Time.current)
    SolidQueue::Process.create!(
      kind: kind, name: name, pid: pid, hostname: "test-host",
      created_at: created_at, last_heartbeat_at: last_heartbeat_at
    )
  end
end
