# API Access

The app has no separate API namespace: the regular RESTful controllers serve
JSON when requested with a `.json` extension (or an `Accept: application/json`
header) and authenticated with an API token.

## Creating a token

1. Open your profile (click your name in the sidebar).
2. In the **API Tokens** section, enter a name, choose a **scope** (`Read write`
   or `Read only` — see [Token scopes](#token-scopes)), optionally set an expiry
   date, and click **Create token**.
3. Copy the plaintext token (`lmt_...`) from the banner — it is shown exactly
   once. Only a SHA-256 digest is stored server-side.

Scope is fixed when the token is created; to change it, revoke the token and
issue a new one (which mints a new secret).

Tokens can be revoked from the same section at any time. Revocation is
immediate and permanent; the row is kept for the audit trail.

## Authenticating requests

Send the token as a Bearer token. A token carries the permissions of the user
who created it — the same Pundit policies apply as in the browser — optionally
narrowed by its [scope](#token-scopes).

```sh
curl -H "Authorization: Bearer lmt_..." https://example.com/properties.json
```

When an `Authorization` header is present, session cookies are ignored: an
invalid, revoked, or expired token yields `401 Unauthorized` even if you are
signed in to the browser session.

## Token scopes

Every token carries a coarse scope, chosen at creation:

- **`read_write`** (default) — the token behaves exactly as before: it carries
  the full permissions of its user.
- **`read_only`** — the token may make only safe (`GET`/`HEAD`) requests. Any
  `POST`, `PATCH`, `PUT` or `DELETE` is rejected with `403 Forbidden` and
  `{"error": "..."}` **before** the action (and before Pundit) runs. This
  includes member "action" endpoints that mutate over a `PATCH`
  (`invoice_notifications`' `approve`/`approve_all`/`retry`/`cancel`) and
  `invoice_templates#preview` (routed over `POST`/`PATCH`, so verb-blocking
  denies it even though it only reads — consistent with `invoice_templates`
  being mutations-only over the API).

Scope only ever *narrows* the user's Pundit permissions; it never widens them.
A `read_only` token on an admin account still cannot write, and a `read_write`
token gets no more than the user's own policies already allow.

`read_only` covers "read-only access to my own account" without inventing a
shadow low-privilege user. For needs narrower than read/write (e.g. access to
only a subset of resources), issue a token from a dedicated user whose
`user_associations` grant exactly that — the same pattern used before scopes.

**The invariant scopes rest on:** no `GET`/`HEAD` route reachable by a token
holder mutates state, so allowing only safe verbs is a sound read-only gate.
Two writes-on-a-safe-verb are known and out of reach from a `read_only` token:
`sessions#create` (the OAuth callback is a `GET`, but it needs
`omniauth.auth` from the OmniAuth middleware and is never a token request) and
`ApiToken#touch_last_used` (a benign `last_used_at` bump on every authenticated
`GET`). A route-walk regression spec guards this invariant against future
drift.

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
Reports and session endpoints are HTML-only.

Responses serialize a record's full attribute set (Rails' default
`render json:`) — a deliberate v1 decision, bounded by two guardrails: you
only ever receive records the token's user is authorized to see (the same
Pundit policies and scopes as the browser UI), and credentials are never
serialized (API tokens have no read endpoint, and token digests are excluded
from the audit trail). A field-level serializer layer is deferred until a
consumer needs a stable, narrower contract.

## Responses and errors

| Status | Meaning | Body |
| ------ | ------- | ---- |
| 200 / 201 | Success | The record or collection as JSON |
| 204 | Successful delete | empty |
| 401 | Missing/invalid/revoked/expired token | `{"error": "Unauthorized"}` |
| 403 | Token user lacks permission (Pundit) | `{"error": "..."}` |
| 403 | `read_only` token attempting a write | `{"error": "This API token is read-only and cannot perform write operations."}` |
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
