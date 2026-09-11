# Deployment — Dokku on Hetzner

This is the deployment guide **and the BC/DR runbook** for Lease Manager. It describes the platform
that actually exists today. If you are recovering the service, start at
[Rebuilding from scratch](#rebuilding-from-scratch).

> **This application is live and carries real users.** There is no staging environment.

## At a glance

| | |
|---|---|
| Platform | [Dokku](https://dokku.com) on a Hetzner CX22 VM |
| Host | `91.98.73.173` (SSH as the `dokku` user) |
| Dokku app | `lease-manager` |
| Database | Dokku Postgres service `lease-manager-db`, linked to the app |
| Public URL | <https://lease-manager.loonyb.in> |
| DNS | Cloudflare (`loonyb.in` zone) in front of the host |
| TLS at the origin | Let's Encrypt, via the `dokku-letsencrypt` plugin |
| Build | The repository `Dockerfile` (Dokku's dockerfile builder) |
| Processes | `Procfile` — `web` (Thruster + Rails) and `worker` (Solid Queue) |
| Deploy trigger | `.github/workflows/deploy.yml`, on a successful CI run on `main` |
| File storage | Backblaze B2 bucket `lease-manager` (see `config/storage.yml`) |

---

## A merged PR is a production release

Read this before you merge anything.

`.github/workflows/deploy.yml` is triggered by `workflow_run` on the **CI** workflow, filtered to
the `main` branch, and runs when that CI run concluded `success`. It then pushes the exact commit CI
tested to the Dokku host:

```
git push dokku@91.98.73.173:lease-manager HEAD:refs/heads/main --force
```

So:

- **Merging a pull request into `main` deploys it to production.** Nothing else is required and
  nobody is asked.
- **There is no staging environment** and **no manual approval gate** between merge and production.
- **Migrations run on every deploy.** `app.json` declares a Dokku `predeploy` task of
  `bundle exec rails db:prepare`, which Dokku runs in a container built from the new image, before
  the new release takes traffic. A failing migration fails the deploy and the old release keeps
  serving.
- CI failing is the only thing standing between a bad commit and production. A red CI run means no
  deploy; a green one means a deploy.
- The deploy job uses `concurrency: deploy-production` with `cancel-in-progress: true`, so rapid
  merges can cancel an in-flight deploy.

Whether this should remain the arrangement is an open question for the repository owner, not a
settled design.

### Deploy credentials

| Where | Name | What it is |
|---|---|---|
| GitHub Actions secret | `DOKKU_SSH_PRIVATE_KEY` | Private key whose public half is registered with `dokku ssh-keys:add` on the host |

The workflow currently trusts the host key on first contact (`ssh-keyscan` at deploy time) rather
than pinning a known fingerprint. Pinning it is tracked as deploy-safety work and is not done here.

---

## Configuration

### Config vars on the Dokku app

Read them with `ssh dokku@91.98.73.173 config:show lease-manager`.

| Var | Set by | Purpose |
|---|---|---|
| `DATABASE_URL` | `dokku postgres:link` | Primary database. Also holds the Solid Queue, Solid Cache and Solid Cable tables — there is no separate queue database. |
| `RAILS_MASTER_KEY` | **the repository owner, by hand** | Decrypts `config/credentials.yml.enc`: Google OAuth client ID/secret and the Backblaze B2 keys. |
| `APP_HOST` | `bin/bootstrap` | `lease-manager.loonyb.in`. Feeds `config.hosts` (DNS-rebinding protection) and mailer URL generation. Without it, mailer links are generated against `example.com`. |

Optional vars the application reads, all with working defaults — see
`config/environments/production.rb`, `config/puma.rb` and `config/queue.yml`:

`FORCE_SSL` (default `true`), `RAILS_LOG_LEVEL` (`info`), `RAILS_MAX_THREADS` (`3`),
`WEB_CONCURRENCY`, `JOB_CONCURRENCY` (`1`), `SOLID_QUEUE_IN_PUMA`, `API_RATE_LIMIT`,
`API_RATE_LIMIT_PERIOD`, `MAIL_FROM`.

### `config/master.key` is owned by the repository owner

**Standing rule: agents never read, copy, move or regenerate the Rails master key.** It is not in the
repository and it is not recoverable from anything here.

**A rebuild cannot proceed past `bin/bootstrap` without it.** The key must come from the repository
owner, who is its only source. `bin/bootstrap` deliberately stops with an error rather than deploying
an app that cannot decrypt its credentials.

Without the key the application will not boot, will not authenticate anyone through Google OAuth,
and will not reach the B2 bucket. This is a known single point of failure and it is accepted
deliberately.

---

## What runs in production

`Procfile`:

```
web: ./bin/thrust ./bin/rails server
worker: bundle exec rake solid_queue:start
```

**The `worker` process is what makes the business run.** `solid_queue:start` runs the Solid Queue
supervisor, which includes the recurring scheduler that reads `config/recurring.yml`:

| Task | Schedule | What happens if it does not run |
|---|---|---|
| `generate_monthly_invoices` | `5 0 1 * *` | **No rent invoices are created for the month.** |
| `schedule_invoice_reminders` | `30 1 * * *` | No payment reminders are sent. |
| `clear_solid_queue_finished_jobs` | hourly at :12 | Finished job rows accumulate. |

> **Dokku scales every non-`web` process type to 0 on a new app.** A freshly created app therefore
> deploys successfully, serves pages, looks entirely healthy — and silently bills nobody. This is
> the single easiest way to get a rebuild wrong.

Check and fix:

```bash
ssh dokku@91.98.73.173 ps:scale lease-manager             # expect: web: 1, worker: 1
ssh dokku@91.98.73.173 ps:scale lease-manager worker=1
```

`bin/bootstrap` sets `worker=1` when it finds it at 0, and otherwise leaves the scale alone.

The alternative arrangement — running the supervisor inside Puma by setting `SOLID_QUEUE_IN_PUMA`
(see `config/puma.rb`) — is **not** what this app uses. It runs a separate `worker` process. Do not
set both.

### Verifying jobs have actually fired

```bash
ssh dokku@91.98.73.173 postgres:connect lease-manager-db
```

```sql
-- Supervisor and workers currently registered (rows disappear when nothing is running)
SELECT kind, name, last_heartbeat_at FROM solid_queue_processes ORDER BY last_heartbeat_at DESC;

-- Recurring tasks the scheduler knows about
SELECT key, schedule, static FROM solid_queue_recurring_tasks;

-- Did the monthly invoice run fire, and when?
SELECT task_key, run_at FROM solid_queue_recurring_executions ORDER BY run_at DESC LIMIT 20;

-- Anything that blew up
SELECT id, created_at FROM solid_queue_failed_executions ORDER BY created_at DESC LIMIT 20;
```

---

## Rebuilding from scratch

This is the disaster-recovery path: a new Hetzner VM, nothing on it.

**Before you start, get `RAILS_MASTER_KEY` from the repository owner.** You cannot finish without it.

### 1. Provision the host

A Hetzner CX22 (or larger) running a Dokku-supported Ubuntu LTS. Open ports 22, 80 and 443.

### 2. Install Dokku and its plugins

```bash
# On the new host, as root. Check https://dokku.com/docs/getting-started/installation/
# for the current release before pasting a version number.
wget -NP . https://dokku.com/bootstrap.sh
sudo DOKKU_TAG=v0.35.20 bash bootstrap.sh

sudo dokku plugin:install https://github.com/dokku/dokku-postgres.git postgres
sudo dokku plugin:install https://github.com/dokku/dokku-letsencrypt.git letsencrypt
```

### 3. Register the deploy keys

```bash
# Your own key, so bin/bootstrap and every command in this runbook works
cat ~/.ssh/id_ed25519.pub | ssh root@NEW_HOST dokku ssh-keys:add admin

# The CI deploy key — the public half of the GitHub secret DOKKU_SSH_PRIVATE_KEY
ssh root@NEW_HOST dokku ssh-keys:add github-actions < deploy_key.pub
```

### 4. Create the app and set the master key

```bash
ssh dokku@NEW_HOST apps:create lease-manager
ssh dokku@NEW_HOST config:set lease-manager RAILS_MASTER_KEY=<key from the repository owner>
```

### 5. Run the bootstrap script

`bin/bootstrap` in this repository is the authoritative first-time setup. It is idempotent, it never
overrides operator-owned runtime state such as a manual scale-up, and it is the single thing to run
whenever you suspect server-side drift.

```bash
DOKKU_HOST=dokku@NEW_HOST bin/bootstrap
```

It creates the app if it is missing; creates the `lease-manager-db` Postgres service and links it
(which is what sets `DATABASE_URL`); sets the domain and `APP_HOST`; **fails loudly if
`RAILS_MASTER_KEY` is missing**; scales `worker` to 1 if it is at 0; configures Let's Encrypt; and
installs the certificate auto-renew cron job.

### 6. First deploy

Either merge anything to `main` and let CI deploy it, or push by hand from a clone:

```bash
git remote add dokku dokku@NEW_HOST:lease-manager
git push dokku main:refs/heads/main --force
```

The `predeploy` task creates the schema on an empty database.

> **Watch the seed step.** `rails db:prepare` runs `db:seed` when it is the call that creates the
> database. `db/seeds.rb` refuses to seed when `RAILS_ENV=production` and returns immediately, so a
> production rebuild gets a schema and no rows. If you are restoring real data, that is what you
> want — restore it in the next step.

### 7. Restore the data

See [Database backup and restore](#database-backup-and-restore) below.

### 8. Issue the certificate

Run `bin/bootstrap` a second time. The first run skips certificate issuance because Let's Encrypt
cannot validate a domain for an app that has never deployed.

```bash
DOKKU_HOST=dokku@NEW_HOST bin/bootstrap
```

### 9. Point DNS at the new host

In the [Cloudflare dashboard](https://dash.cloudflare.com) for `loonyb.in`, update the
`lease-manager` record to the new host's IP address.

### 10. Update the things that hold the old IP address

- `.github/workflows/deploy.yml` — the host address appears in the push target and in the
  `ssh-keyscan` step.
- Google OAuth: the authorised origin and redirect URI
  (`https://lease-manager.loonyb.in/auth/google_oauth2/callback`) are keyed to the domain, not the
  IP, so they only need attention if the domain changes.
- This file.

### 11. Verify

```bash
curl -sSf https://lease-manager.loonyb.in/up                 # health endpoint, 200
ssh dokku@NEW_HOST ps:scale lease-manager                    # web: 1, worker: 1
ssh dokku@NEW_HOST ps:report lease-manager --deployed        # true
ssh dokku@NEW_HOST letsencrypt:list                          # certificate present, not expiring
```

Then log in through Google OAuth and open a lease — that exercises the master key, the database and
the B2 bucket in one go.

---

## Database backup and restore

> **Scheduled off-host backups are not in place yet.** At the time of writing, the only copy of
> production data is the Postgres service on the application host. Establishing off-host backups and
> rehearsing a restore end to end is tracked separately and is not done. **Do not treat the commands
> below as evidence that a backup exists — check for one before you rely on it.**

### Take a dump now

```bash
ssh dokku@91.98.73.173 postgres:export lease-manager-db > lease-manager-$(date +%F).dump
```

`postgres:export` writes a `pg_dump` custom-format archive to stdout. Move it off the host
immediately.

### Restore into a service

```bash
# Into a fresh service on a rebuilt host
ssh dokku@NEW_HOST postgres:import lease-manager-db < lease-manager-2026-01-01.dump
```

Restore into an **empty** service. `postgres:import` does not drop existing objects first.

### After any restore

```bash
ssh dokku@NEW_HOST run lease-manager bundle exec rails db:migrate
ssh dokku@NEW_HOST ps:restart lease-manager
```

The dump carries the schema as of the moment it was taken; if the deployed code is newer, migrate.

### The Dokku Postgres plugin's own backup support

The plugin can push scheduled dumps to any S3-compatible bucket, which is the obvious fit here given
the app already uses Backblaze B2:

```bash
dokku postgres:backup-auth  lease-manager-db AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY \
                            eu-central-003 s3v4 https://s3.eu-central-003.backblazeb2.com
dokku postgres:backup-schedule lease-manager-db "0 3 * * *" BUCKET_NAME
dokku postgres:backup-set-encryption lease-manager-db PASSPHRASE
```

Use a **separate bucket and a separate application key** from the one the app uses for uploads — a
backup that a compromised application can delete is not a backup.

---

## Routine operations

All commands run over SSH against the Dokku host. `ssh dokku@91.98.73.173 <command>` is equivalent to
`dokku <command>` on the host itself.

```bash
# Logs
ssh dokku@91.98.73.173 logs lease-manager --tail
ssh dokku@91.98.73.173 logs lease-manager --ps worker --tail

# Rails console (be careful, this is production)
ssh -t dokku@91.98.73.173 run lease-manager bundle exec rails console

# One-off task
ssh dokku@91.98.73.173 run lease-manager bundle exec rails runner 'puts Invoice.count'

# Restart without redeploying
ssh dokku@91.98.73.173 ps:restart lease-manager

# What is deployed, and how it is configured
ssh dokku@91.98.73.173 ps:report lease-manager
ssh dokku@91.98.73.173 config:show lease-manager
ssh dokku@91.98.73.173 ports:list lease-manager
ssh dokku@91.98.73.173 domains:report lease-manager
```

`dokku run` starts a **new one-off container** from the deployed image. `dokku enter lease-manager
web` attaches to a running one.

### Rolling back

There is no `dokku rollback`. Options, best first:

1. **Revert on GitHub.** `git revert` the bad commit, open a PR, merge it. CI runs, the deploy
   workflow fires, production returns to the previous behaviour. This is the only route that keeps
   `main` and production in agreement — prefer it.

2. **Push the previous commit straight to the host.** Faster, and leaves `main` ahead of production
   until you reconcile it. Needs a key registered with `dokku ssh-keys:add`.

   ```bash
   git push dokku@91.98.73.173:lease-manager <good-sha>:refs/heads/main --force
   ```

   This rebuilds from source, so it is not instant, and the `predeploy` `db:prepare` runs again.

3. **Scale to zero** if the application is actively doing damage and you need it stopped:
   `ssh dokku@91.98.73.173 ps:scale lease-manager web=0 worker=0`. Users get an error page.
   Remember to scale back up.

**Migrations do not roll back with the code.** A revert of a commit that added a migration does not
undo the schema change; the reverted code then runs against the migrated schema. Reverting a
destructive migration is a manual, data-level job — think before merging one.

### Secret rotation

```bash
ssh dokku@91.98.73.173 config:set lease-manager RAILS_MASTER_KEY=<new key>
```

`config:set` restarts the app. Rotating the master key means re-encrypting
`config/credentials.yml.enc` in the repository with the new key and deploying that commit — the two
have to land together or the app cannot decrypt its credentials. Coordinate with the repository
owner; do not attempt it unattended.

---

## TLS and DNS

Two layers, and both have to be healthy:

1. **Cloudflare** serves `lease-manager.loonyb.in` to the public and terminates TLS at its edge.
2. **Dokku's nginx** terminates TLS at the origin using a Let's Encrypt certificate obtained by the
   `dokku-letsencrypt` plugin. Cloudflare validates this certificate when its SSL mode is
   Full (strict).

An expired origin certificate therefore takes the site down **even though Cloudflare's own edge
certificate is fine** — that is what caused the outage on 2026-07-09. The fix, and the reason
`bin/bootstrap` exists, is the plugin's renewal cron job:

```bash
ssh dokku@91.98.73.173 letsencrypt:list             # expiry dates per app
ssh dokku@91.98.73.173 letsencrypt:cron-job --add   # idempotent; installs the daily renew job
ssh dokku@91.98.73.173 letsencrypt:enable lease-manager   # force re-issue
```

Certificate issuance needs port 80 reachable from the internet for the ACME HTTP-01 challenge. If
Cloudflare proxying interferes with issuance, pause the proxy (grey cloud) for the duration.

The application trusts the proxy in front of it: `config.assume_ssl` and `config.force_ssl` are both
on by default in production, controlled by `FORCE_SSL`. `/up` is excluded from the HTTPS redirect
and from host authorisation so health checks work regardless.

---

## Troubleshooting

**The site returns 502, but `ps:report` says the app is deployed and running.**
Check the port mapping against what the web process is actually listening on:

```bash
ssh dokku@91.98.73.173 ports:list lease-manager    # e.g. http:80:8080
ssh dokku@91.98.73.173 config:get lease-manager HTTP_PORT
```

Dokku takes the container-side port from the `Dockerfile`'s `EXPOSE`, which is `8080` here.
Thruster — the `web` process — listens on `HTTP_PORT`, which **defaults to 80**, not 8080. The two
must agree, so a working app has either `HTTP_PORT=8080` in its config or a port mapping that ends
in 80. Copy whichever arrangement the live host uses; a rebuild that gets this wrong looks perfectly
healthy and serves nothing.

**Invoices were not generated on the 1st.**
Check `ps:scale` for `worker: 0` first — see [What runs in production](#what-runs-in-production).
Then check `solid_queue_recurring_executions` and `solid_queue_failed_executions`.

**Deploy succeeded but the change is not live.**
The deploy workflow deploys `github.event.workflow_run.head_sha` — the commit CI tested, which may
not be the tip of `main` if merges raced. Check `ps:report lease-manager` for the deployed SHA.

**Deploy never ran after a merge.**
The deploy workflow only fires when the CI run concluded `success` on `main`. Check the CI run, not
the deploy workflow.

**`Blocked hosts` error in the logs.**
`APP_HOST` is unset or does not match the domain being requested. `bin/bootstrap` fixes it.

**The app boots but cannot decrypt credentials.**
`RAILS_MASTER_KEY` is missing or wrong. Only the repository owner can supply it.

---

## Known gaps

Recorded here so a reader is not misled by omission:

- **No scheduled off-host database backup, and no rehearsed restore.** Tracked separately.
- **The deploy workflow does not pin the Dokku host key**; it trusts it on first contact at deploy
  time.
- **The host IP is hardcoded** in `.github/workflows/deploy.yml` rather than held in a repository
  variable.
- **No monitoring or alerting.** Nothing pages anyone if `/up` stops answering, if the certificate
  approaches expiry, or if the `worker` process stops.
- **`RAILS_MASTER_KEY` exists in exactly one place** outside the repository owner's own copy: the
  Dokku config for this app.
- **The live values of `HTTP_PORT` and the port mapping are not recorded in this repository** — they
  can only be read off the running host. Capture them here the next time someone has host access.
