# frozen_string_literal: true

# Release verification endpoints.
#
# `/up` (Rails' own health check) answers exactly one question: did the process
# boot far enough to serve a request? It never touches the database, so a
# release that comes up against an unreachable or unmigrated database still
# answers 200 and the deploy reports success. These two endpoints answer the
# questions a release actually turns on:
#
#   GET /health/ready   - can this container serve real requests? Database
#                         reachable, no migrations pending, domain tables
#                         readable.
#   GET /health/workers - is a Solid Queue worker alive and heartbeating?
#
# The worker lives on its own path rather than inside /health/ready on purpose.
# A dead worker must not block a web release: the release being held back may
# well be the one that fixes it. Callers that want both ask for both, which is
# what bin/verify-release does.
#
# Both are public, like /up, and both are deliberately data-free: statuses,
# counts, timestamps and durations only. A failing check reports the exception's
# class name and never its message, because a message can carry a connection
# string, a fragment of SQL or a row value, and this response goes to an
# unauthenticated caller. The full message is written to the log instead.
# ActionController::Base, not ApplicationController, is deliberate and doing
# three jobs at once. ApplicationController redirects an unauthenticated caller
# to the sign-in page, so a health check would be answered with a 302 and a
# monitor would call that healthy. It also runs Pundit's after_action, the API
# token guard and the token rate limiter, none of which have anything to say
# about a health check. And ApiToken::PermissionRegistry derives its grantable
# permissions from every controller that descends from ApplicationController —
# inheriting would add "health#ready" to the token permission matrix as a
# capability someone could tick, which it is not.
# rubocop:disable Rails/ApplicationController
class HealthController < ActionController::Base
  # rubocop:enable Rails/ApplicationController
  OK = "ok"
  ERROR = "error"

  # Solid Queue names process rows after the demodulized class that registered
  # them (SolidQueue::Processes::Base#kind), so a worker row is "Worker". The
  # supervisor, dispatcher and scheduler register under their own kinds; only a
  # worker actually runs jobs, so only a worker is asked about here.
  WORKER_KIND = "Worker"

  def ready
    checks = {
      database: check("database") { ActiveRecord::Base.with_connection { |c| c.select_value("SELECT 1") } },
      migrations: check("migrations") { ActiveRecord::Migration.check_all_pending! },
      # A migration can be marked applied and the table still be missing (a
      # half-run schema load, a restore from the wrong dump). Reading one row
      # from a core table proves the model, its table and the connection agree.
      domain_tables: check("domain_tables") { Lease.limit(1).pick(:id) }
    }

    healthy = checks.each_value.all? { |result| result[:status] == OK }
    render json: { status: healthy ? OK : ERROR, checks: checks },
           status: healthy ? :ok : :service_unavailable
  end

  def workers
    payload = worker_payload
    render json: payload, status: payload[:status] == OK ? :ok : :service_unavailable
  end

  private

  def check(name)
    yield
    { status: OK }
  rescue StandardError => e
    log_failure(name, e)
    { status: ERROR, error: e.class.name }
  end

  def worker_payload
    stale_after = SolidQueue.process_alive_threshold.to_i
    live = SolidQueue::Process.where(kind: WORKER_KIND).where(last_heartbeat_at: stale_after.seconds.ago..)
    newest = live.order(created_at: :desc).first

    return { status: ERROR, error: "no_live_worker", live_workers: 0, stale_after_seconds: stale_after } if newest.nil?

    { status: OK, live_workers: live.count, stale_after_seconds: stale_after,
      newest_worker: newest_worker_payload(newest) }
  rescue StandardError => e
    log_failure("workers", e)
    { status: ERROR, error: e.class.name }
  end

  # started_seconds_ago is what a release check compares against: a worker that
  # started longer ago than the deploy has been running is the *old* worker,
  # still heartbeating because Dokku has not retired it yet. The absolute
  # timestamps are here for a human reading the endpoint by hand.
  def newest_worker_payload(process)
    now = Time.current
    {
      started_at: process.created_at.utc.iso8601,
      started_seconds_ago: (now - process.created_at).round,
      last_heartbeat_at: process.last_heartbeat_at.utc.iso8601,
      last_heartbeat_seconds_ago: (now - process.last_heartbeat_at).round
    }
  end

  def log_failure(name, error)
    Rails.logger.error("[health] #{name} check failed: #{error.class}: #{error.message}")
  end
end
