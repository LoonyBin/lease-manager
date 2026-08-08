# API Access

The app has no separate API namespace: the regular RESTful controllers serve
JSON when requested with a `.json` extension (or an `Accept: application/json`
header) and authenticated with an API token.

## Creating a token

1. Open your profile (click your name in the sidebar).
2. In the **API Tokens** section, enter a name, choose which **permissions**
   the token carries (a preset — `Read only` or `Full access` — or `Custom`
   with an individual controller×action matrix; see
   [Token permissions](#token-permissions)), optionally set an expiry date, and
   click **Create token**.
3. Copy the plaintext token (`lmt_...`) from the banner — it is shown exactly
   once. Only a SHA-256 digest is stored server-side.

Permissions are fixed when the token is created; to change them, revoke the
token and issue a new one (which mints a new secret).

Token creation and revocation are **browser-session only**. No API token can
create or revoke tokens — a credential may never manage credentials (see
[Token permissions](#token-permissions)) — so these steps cannot be automated
with a token.

Tokens can be revoked from the same section at any time. Revocation is
immediate and permanent; the row is kept for the audit trail.

## Authenticating requests

Send the token as a Bearer token. A token carries the permissions of the user
who created it — the same Pundit policies apply as in the browser — narrowed to
the set of actions it was [granted](#token-permissions).

```sh
curl -H "Authorization: Bearer lmt_..." https://example.com/properties.json
```

When an `Authorization` header is present, session cookies are ignored: an
invalid, revoked, or expired token yields `401 Unauthorized` even if you are
signed in to the browser session.

## Token permissions

A token carries an explicit **set of `controller#action` grants**, chosen at
creation. On every token request a credential-level guard asks one question —
*may this token invoke `controller#action`?* — and returns `403 Forbidden` with
`{"error": "..."}` **before** the action runs if the answer is no. If the
answer is yes, the request is handed to Pundit unchanged.

### The model: a chain in front of Pundit, not an intersection

The token check and Pundit are two layers in sequence, not a set intersection:

1. **The token guard** decides whether this *credential* may reach the action
   at all. It knows nothing about records.
2. **Pundit** then decides — exactly as it does for a browser session — whether
   this *user* may perform this action on this *record*, and `policy_scope`
   decides *which* records an `index` returns.

Because the guard runs first and Pundit runs after, a token can only ever
**narrow**, never widen: granting `invoices#index` says only that the token may
*reach* that action; Pundit still refuses if the user may not, and still limits
the collection to the invoices they may see. A token whose grant list includes
an action its user is not authorized for still gets Pundit's `403`.

### Grantable actions are derived from the routes

The grantable rows are not a curated taxonomy — they are every routable action,
read directly from the route table, so **a new controller action is denied by
construction**: it is in no existing token's set until someone grants it, and
there is no mapping layer that could drift or fail open. A grant for an action
that is later renamed simply stops matching (it fails closed, denying access)
and is surfaced in the token UI as a **stale grant** you can only fix by
revoking and re-issuing.

Two kinds of action are not grantable:

- **`new`/`edit` and other HTML-only actions** render forms and have no JSON
  branch, so a credential could never use them. This is best-effort noise
  reduction, not a security boundary — the denial still comes from "not in the
  set".
- **`api_tokens#*` and `sessions#*`** are excluded as a security boundary.
  `sessions` needs the browser session / OmniAuth and is never token-usable.
  `api_tokens` can never be reached by a token at all (below).

### Presets

Two presets expand, server-side, to a canonical set:

- **`Full access`** — every grantable action as of creation. Enumerated, not a
  wildcard: a full-access token does **not** silently gain a *future* action
  (denied-by-construction holds for it too).
- **`Read only`** — the `GET`/`HEAD`-reachable subset. This reproduces the old
  coarse read-only scope exactly, and is the migration target for tokens that
  were `read_only` before this feature.

`Custom` grants exactly the actions you tick. For needs narrower still (e.g.
only a *subset of records*), issue a token from a dedicated user whose
`user_associations` grant exactly that — record-level scoping stays that
mechanism's job, deliberately kept out of token permissions.

### Immutability

A token's permissions (and its preset label) are fixed at creation; there is no
edit endpoint and the columns are `attr_readonly`. Changing what a credential
may do means revoke-and-reissue, which mints a new secret — a capability change
is never silent. The cost is that a stale grant (from a renamed route) cannot be
repaired in place.

### A token may never manage tokens

`ApiTokensController` (token creation and revocation) is unreachable by any API
token. This is a hard invariant enforced by an unconditional early exit in the
guard — **not** a permission that happens to be un-granted — so no stored grant,
preset, or registry entry can ever switch it on. Even a token whose stored
permission set explicitly contains `api_tokens#create` is refused, and mints
nothing. Token management is browser-session only.

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
| 403 | Token user lacks permission (Pundit) | `{"error": "You are not authorized to perform this action."}` |
| 403 | Token not granted this `controller#action` (incl. any `api_tokens#*`) | `{"error": "This API token is not permitted to perform this action."}` |
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
