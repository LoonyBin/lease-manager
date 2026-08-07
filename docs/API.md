# API Access

The app has no separate API namespace: the regular RESTful controllers serve
JSON when requested with a `.json` extension (or an `Accept: application/json`
header) and authenticated with an API token.

## Creating a token

1. Open your profile (click your name in the sidebar).
2. In the **API Tokens** section, enter a name (and an optional expiry date)
   and click **Create token**.
3. Copy the plaintext token (`lmt_...`) from the banner — it is shown exactly
   once. Only a SHA-256 digest is stored server-side.

Tokens can be revoked from the same section at any time. Revocation is
immediate and permanent; the row is kept for the audit trail.

## Authenticating requests

Send the token as a Bearer token. Tokens carry the full permissions of the
user who created them — the same Pundit policies apply as in the browser.

```sh
curl -H "Authorization: Bearer lmt_..." https://example.com/properties.json
```

When an `Authorization` header is present, session cookies are ignored: an
invalid, revoked, or expired token yields `401 Unauthorized` even if you are
signed in to the browser session.

## Endpoints

Standard REST semantics on the existing resources, e.g.:

```sh
# List (paginated with ?page=N, filterable with ransack ?q[...] params)
curl -H "Authorization: Bearer $TOKEN" https://example.com/properties.json

# Show
curl -H "Authorization: Bearer $TOKEN" https://example.com/properties/1.json

# Create
curl -X POST -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"property": {"name": "Villa", "address": "1 Main St", "owner_id": 1, "capacity": 4, "unit": "Rooms"}}' \
  https://example.com/properties.json

# Update
curl -X PATCH -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"property": {"name": "Renamed"}}' \
  https://example.com/properties/1.json

# Delete
curl -X DELETE -H "Authorization: Bearer $TOKEN" https://example.com/properties/1.json
```

Available resources: `properties`, `tenants`, `owners`, `leases`, `payments`,
`invoices` (no delete), `invoice_templates` (nested under
`/leases/:lease_id/`, mutations only), `users`, `user_associations`
(mutations only), and `versions` (the audit trail; read and delete).
Session endpoints are HTML-only; the reports endpoints are documented below.

Responses serialize a record's full attribute set (Rails' default
`render json:`) — a deliberate v1 decision, bounded by two guardrails: you
only ever receive records the token's user is authorized to see (the same
Pundit policies and scopes as the browser UI), and credentials are never
serialized (API tokens have no read endpoint, and token digests are excluded
from the audit trail). A field-level serializer layer is deferred until a
consumer needs a stable, narrower contract.

## Reports

The reports are the only place the app computes aggregates, so unlike the REST
resources they serialize an explicit, hand-picked payload rather than a record's
full attribute set. `GET /` is an alias for `GET /reports` (the app's root).

```sh
curl -H "Authorization: Bearer $TOKEN" https://example.com/reports.json
curl -H "Authorization: Bearer $TOKEN" https://example.com/reports/revenue.json
curl -H "Authorization: Bearer $TOKEN" https://example.com/reports/outstanding.json
curl -H "Authorization: Bearer $TOKEN" https://example.com/reports/taxes.json
```

| URL | Payload keys |
| --- | ------------ |
| `GET /reports.json` | `total_revenue`, `total_outstanding`, `total_taxes`, `total_collected`, `revenue_by_month`, `payments_by_month`, `occupancy_stats`, `invoice_status_distribution` |
| `GET /reports/revenue.json` | `by_month`, `by_property` |
| `GET /reports/outstanding.json` | `total_outstanding`, `invoices` |
| `GET /reports/taxes.json` | `total_taxes`, `by_month` |

- `revenue_by_month`, `payments_by_month`, and both `by_month` maps are keyed by
  a `"%b %Y"` month label (e.g. `"Jan 2026"`). `revenue.by_property` is an array
  of `{ property_id, property, amount }` objects (property names can collide, so
  it is not a name-keyed hash). Each `outstanding.invoices` entry exposes only
  `id`, `number`, `date`, `due_date`, `outstanding_amount`, `lease`, `property`,
  and `tenant` — a trimmed shape, not the full invoice attribute set.
- **Money** is a decimal string, consistent with the rest of the API. Reports
  additionally round it to **at most 2 decimals, not zero-padded** — `"1234.5"`,
  `"0.0"`, `"0.13"` — so each figure matches the (half-up) number the matching
  page shows. This 2-decimal rounding is reports-specific; other endpoints emit
  the column's raw scale, unrounded.
- **`total_outstanding` is two different figures.** On `GET /reports.json` it is
  the balance of every non-cancelled, non-draft invoice — it **includes** paid
  rows and negative credit-note balances. On `GET /reports/outstanding.json` it
  is the sum of only the positive `outstanding_amount`s, **excluding** paid
  invoices. Don't treat the two as the same number.
- **`invoice_status_distribution`** keys are the status enum identifiers
  (`"partially_paid"`, `"finalized"`, …), not display labels.
- Date-range filtering is **not** supported: the charts are the last 12 months
  and the `revenue`/`taxes` tables are all-time. `outstanding` returns **all**
  matching invoices with **no pagination**. JSON object **key order is not part
  of the contract** — the month maps are sorted in Ruby, not guaranteed on the
  wire.

## Responses and errors

| Status | Meaning | Body |
| ------ | ------- | ---- |
| 200 / 201 | Success | The record or collection as JSON |
| 204 | Successful delete | empty |
| 401 | Missing/invalid/revoked/expired token | `{"error": "Unauthorized"}` |
| 403 | Token user lacks permission (Pundit) | `{"error": "..."}` |
| 404 | Record not found / not yours | `{"status": 404, "error": "Not Found"}` |
| 422 | Validation failure | `{"errors": {"field": ["message", ...]}}` |
| 429 | Rate limit exceeded | `{"error": "Rate limit exceeded"}` |

## Rate limiting

Token-authenticated requests are rate limited per token across all
controllers: **300 requests per 5 minutes** by default. Session (browser)
traffic is not rate limited.

The limits are ENV-configurable at deploy time:

| Variable | Default | Meaning |
| -------- | ------- | ------- |
| `API_RATE_LIMIT` | `300` | Requests allowed per window per token |
| `API_RATE_LIMIT_PERIOD` | `300` | Window length in seconds |

Counters are kept in process memory, which is accurate for the single-node
deployment; a multi-node deployment would need a shared cache store
(`ApplicationController`'s `rate_limit store:`).
