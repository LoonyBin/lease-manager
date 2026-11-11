# Security tooling and review

Lease Manager handles tenant information, property access, invoices, payments,
and stored documents. Security review considers those behaviors alongside the
automated checks below. This document describes tooling and review scope, not
findings or vulnerability details.

## CI security checks

The jobs in [`.github/workflows/ci.yml`](../.github/workflows/ci.yml) run on pull
requests and pushes to `main`:

| Job | What it checks | Command |
| --- | --- | --- |
| `scan_ruby` | Brakeman static analysis of Rails application code | `bin/brakeman --no-pager --ensure-latest 7` |
| `scan_js` | Known advisories for JavaScript dependencies managed by Importmap | `bin/importmap audit` |
| `scan_gems` | Known Ruby dependency advisories against `Gemfile.lock`, after refreshing the advisory database | `bundle-audit check --update` |

[`bin/brakeman`](../bin/brakeman) already prepends `--ensure-latest 7` itself, so the
flag is repeated in CI only to make the check visible. It fails the scan when the
installed Brakeman is more than 7 days behind the newest release, so a stale
scanner cannot pass silently; the `7` is a grace period in days, not a version.

## Run locally

Run commands from the repository root with the Ruby version in
[`.ruby-version`](../.ruby-version). For `scan_ruby` and `scan_js`, install the
application bundle, including development dependencies:

```bash
bundle install
bin/brakeman --no-pager --ensure-latest 7
bin/importmap audit
```

`bin/importmap` loads the Rails application, so it needs the application's local
configuration and native libraries. In particular, `ruby-vips` loads libvips;
CI installs it on Ubuntu with:

```bash
sudo apt-get update && sudo apt-get install -y libvips-dev
```

Install the equivalent libvips package for your operating system when running
locally. See the [setup instructions](../README.md#getting-started).

The gem audit is independent of the application bundle. Match CI by installing
the standalone tool and running it directly:

```bash
gem install bundler-audit --no-document
bundle-audit check --update
```

CI deliberately disables Bundler caching for `scan_gems`: bundler-audit reads
`Gemfile.lock` without installing the application gems and is not in `Gemfile`.
Use `bundle-audit`, not an assumed `bin/bundler-audit` wrapper. Installing tools,
refreshing advisories, checking scanner freshness, and querying the JavaScript
advisory service require network access.

These scans complement application tests and review. Passing them alone does
not prove that access controls, privacy, or financial behavior are correct.
See [Testing](TESTING.md) and the [dependency merge rules](DEPENDENCIES.md).

## Changes that need security review

- **Sign-in and sessions:** Google OAuth, developer authentication, session
  cookies, API tokens, and selection of the current user.
- **Who can see or change what:** Pundit policies and scopes, role boundaries
  between admins, owners, and tenants, and browser/API authorization.
- **Tenant personal data:** collection, display, exports, logs, audit history,
  and data sent to error reporting or other external services.
- **Money:** invoice expressions and rounding, taxes, deposits, payments,
  refunds, settlements, and ledger entries, including dependencies used there.
- **File storage:** Active Storage attachments, upload/download access, blob
  storage credentials, image processing, and storage configuration.
- **Secrets:** Rails credentials, environment variables, API keys, and any
  handling or logging of production secrets.
- **CI and deployment:** workflow permissions and actions, build dependencies,
  container configuration, deploy credentials, and production configuration.

Use the [architecture documentation](ARCHITECTURE.md) to trace affected
components. Keep credentials, tenant data, and private vulnerability details
out of this public repository and public review discussions.
