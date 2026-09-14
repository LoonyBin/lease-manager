# Lease Manager

A comprehensive property and lease management application built with Ruby on Rails 8. This application handles complex lease scenarios, automated financial workflows, and multi-party resource management.

## Key Features

### 1. Core Management
- **Multi-Owner Support**: Manage properties across multiple legal owners, each with distinct invoice sequencing.
- **Property & Unit Management**: Track properties with capacity management (e.g., partial leasing of areas or rooms) and define layout and schedules.
- **Tenant Management**: Centralized tenant profiles and history.

### 2. Lease Lifecycle
- **Flexible Terms**: Supports calendar-aware payment terms allowing complex dynamic duration configurations. Includes fixed-term leases with automatic end date calculations.
- **Partial Leasing**: Validates and tracks capacity usage (e.g., leasing 500sqft of a 1000sqft property) and quantity details (with units).
- **Property Schedules**: Dedicated tracking of schedules directly linked to the lease.
- **Rent Enhancements**: Automated rent escalation configurations (percentage or fixed amount) over time.
- **Renewals & Terminations**: Guided workflows for extending leases, carrying over schedules, or ending early.
- **Filtering**: Filter leases by dynamic statuses.

### 3. Financial Engine
- **Automated Invoicing**: Generation of rent invoices with tax calculations.
- **Security Deposits**: Automated invoicing and credit note generation for security deposits (supports both months-based decimals and fixed amounts) upon lease creation and termination.
- **Lease Statement**: Provides a consolidated chronological ledger of invoices, payments, and credit notes for a specific lease.
- **Payment Workflow**: Status-driven lifecycle (`draft` → `confirmed` → `partially_allocated` / `fully_allocated`) with `rejected` support. Covers both payments and refunds.
- **Settlements**: Polymorphic payment allocation system backed by double-entry ledger records (`Entry`). Payments can be split and allocated across multiple invoices or credit notes automatically.
- **Reporting**: Dashboards featuring interactive graphic charts for Revenue, Occupancy rates, and aggregated Cached Outstanding Balances.

### 4. Security & Auditing
- **Role-Based Access Control (RBAC)**: Secure access for Admins, Owners (who seamlessly create leases for their properties), and Tenants using Pundit policies.
- **Audit Trails**: Full history tracking of all changes (Create, Update, Destroy) for critical resources using PaperTrail.
- **Authentication**: Modern OAuth integration via Google (credentials managed securely via Rails credentials) alongside developer login support.

### 5. Backend & Deployment
- **Background Jobs**: Integrated with Rails 8 Solid Queue for reliable, database-backed job orchestration.
- **Deployment Strategy**: Deployed to Dokku on a VM. The application follows 12-factor principles, isolating architecture from the specific deployment target.

### 6. User Interface
- **Responsive Design**: Mobile-friendly layouts with drawer-based navigation and CSS Grid.
- **Navigation**: Dedicated Finance accordion menu housing Invoices and Payments sub-items.
- **Card & Table Views**: Switchable card and table views on all resource index pages with persistent user preference.
- **Dark Theme**: DaisyUI v5-powered theming with dark mode support.
- **Filtering & Sorting**: Advanced filtering (Ransack) and sort sidebars on all index pages.

## Technology Stack

- **Framework**: Ruby on Rails 8.1
- **Database**: PostgreSQL
- **Frontend**:
  - TailwindCSS 4 (Styling)
  - DaisyUI 5 (Component Library with dark theme)
  - Hotwire (Turbo & Stimulus for reactivity)
  - HAML (Templating)
- **Key Gems**:
  - `pundit`: Authorization
  - `paper_trail`: Audit logging
  - `solid_queue`: Background jobs
  - `heroicons`: Icon library
  - `kaminari`: Pagination
  - `ransack`: Filtering and Sorting
  - `chartkick` / `groupdate`: Visualization

## Getting Started

### Prerequisites
- Check `.ruby-version` for the required Ruby version.
- PostgreSQL installed and running.

### Setup
Run the setup script to install dependencies and prepare the database:

```bash
bin/setup
```

### Running the Server
Start the development server (Rails + Tailwind watcher):

```bash
bin/dev
```

Visit `http://localhost:3000` in your browser.

## Development

### Login
For local development, you can use the default Admin account:
- **Email**: `admin`
- **Role**: Admin

(Note: Authentication uses a developer strategy in non-production environments).

### Testing
This project uses RSpec for testing.

```bash
# Run all tests
bin/rspec

# Run specific file
bin/rspec spec/models/lease_spec.rb
```

### Code Quality
We enforce strict code quality standards using RuboCop and fast suites, automated via `.githooks` for `pre-commit` and `pre-push` triggers.

```bash
# Run linter
bin/rubocop
```

## Releases

A merge to `main` goes live on its own: CI passes, `.github/workflows/deploy.yml`
pushes to Dokku, and eight to twelve minutes later the new version is serving.
There is no human gate, so the deploy has to check its own work.

### What is checked after a release

`bin/verify-release` runs at the end of every deploy, and can be run by hand
against production at any time:

```bash
bin/verify-release                                  # production
APP_URL=http://127.0.0.1:3000 bin/verify-release    # anywhere else
```

It makes a handful of real unauthenticated requests and fails the deploy run —
visibly, in red — if any of them are wrong:

| Request           | What it proves                                          |
| ----------------- | ------------------------------------------------------- |
| `/up`             | the process booted and answers                           |
| `/health/ready`   | the database is reachable, migrated, and readable        |
| `/login`          | a real page still renders (HAML, layout, assets)         |
| `/`               | routing and the sign-in redirect still work              |
| `/invoices.json`  | the JSON API refuses anonymous callers rather than 500ing |
| `/health/workers` | a Solid Queue worker **from this release** is alive       |

The last one is the awkward case: for about a minute after the switch the
previous release's worker is still alive and still heartbeating, so "a worker is
up" is not the same as "the new worker is up". `/health/workers` reports how long
ago the newest live worker started, and the deploy compares that against how long
its own deploy has been running, passed in as `DEPLOY_STARTED_AT`.

Run by hand there is no deploy to be newer than, so that half of the check is
skipped and the run says so at the end. Run from a deploy it is mandatory: a
missing or malformed `DEPLOY_STARTED_AT` is an error, not a quieter pass, because
"a worker is alive" is true of the release being replaced — exactly the failure
the check exists to catch. `REQUIRE_FRESH_WORKER` decides which of those applies
and defaults to on wherever `CI` is set.

### The health endpoints

`/up` is Rails' own health check and answers exactly one question: did the
process boot? It never touches the database, so a release running against an
unreachable or unmigrated database still answers 200. `HealthController` adds two
endpoints that answer the questions a release actually turns on — `/health/ready`
and `/health/workers`. Both are public, like `/up`, both are exempt from host
authorization and the https redirect (`config.x.health_check_paths`), and both
are deliberately data-free: statuses, counts, timestamps and durations, with
exception class names and never exception messages.

### What none of this catches

Everything behind the login. A broken invoice run, a form that no longer saves, a
page that 500s for a signed-in user — none of that is visible to an
unauthenticated check, and a green deploy does not mean none of it happened.
That is what error reporting is for.

## Error reporting

Unhandled exceptions from the website and from the Solid Queue worker are
reported to Sentry, so that a release which boots but is broken behind the
sign-in page says so instead of waiting to be noticed.

**It is inert until someone sets `SENTRY_DSN` on the host.** Without that
variable the gems load, the middleware sees an uninitialised client and passes
every request straight through; nothing is collected and nothing is sent. It is
also never enabled outside production.

```bash
dokku config:set lease-manager SENTRY_DSN='https://…@…ingest.de.sentry.io/…'
dokku config:set lease-manager SENTRY_RELEASE="$(git rev-parse --short HEAD)"  # optional
```

`SENTRY_RELEASE` is optional and only tags reports with the version that
produced them.

### What leaves the server, and what does not

This application holds real tenant and lease data, so the configuration is
written out explicitly in `lib/error_reporting/setup.rb` rather than left to the
gem's defaults, and `spec/lib/error_reporting/setup_spec.rb` asserts every line
of it — a future release of `sentry-ruby` that changes a default has to fail the
build rather than quietly widen what we disclose.

**Not sent:** request and response bodies, cookies, headers of any kind, the
query string, the signed-in user's identity, the caller's IP address, values
bound to a SQL query, queued job payloads, and the local variables in each stack
frame.

**Sent:** the exception's class and message, the stack trace, the URL path — so
record identifiers, `/leases/482/invoices/9911` — the controller and action, and
a breadcrumb trail of what the request was doing.

The message is the unavoidable one. A report without it says only "something
raised `ActiveRecord::StatementInvalid` somewhere", and messages quote values.
`ErrorReporting::MessageScrubber` removes what can be recognised by shape —
email addresses, the value in a Postgres constraint violation's detail line, SQL
string literals, and values assigned to any name in `config.filter_parameters` —
before the report leaves the process. It cannot remove a name or an amount
sitting in prose, and does not pretend to. If scrubbing itself fails, the free
text is withheld wholesale and the report is still sent: the class and the stack
trace are enough to say the site is broken.

## Documentation

For more detailed information, check the `docs/` directory:
- [Architecture](docs/ARCHITECTURE.md): System design, data models, and patterns.
- [Requirements](docs/REQUIREMENTS.md): Detailed feature specifications.
- [Testing](docs/TESTING.md): Testing strategy and guidelines.
