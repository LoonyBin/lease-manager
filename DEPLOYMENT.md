# Deployment — Google Cloud Run

This document describes how to deploy the Lease Manager application to Google Cloud Run and serves as the BC/DR runbook.

## Architecture Overview

```
GitHub Actions (push to main)
  │
  ├── Build & push Docker image → Artifact Registry
  ├── tofu apply (infra drift check + update)
  ├── Cloud Run Job: lease-manager-migrate (rails db:migrate)
  └── Cloud Run Service: lease-manager
        ├── min_instances=0, max_instances=10 (scale-to-zero)
        ├── Cloud SQL Auth Proxy sidecar (PostgreSQL on localhost:5432)
        ├── Secrets injected from Secret Manager
        └── Custom domain: lease-manager.loonyb.in (Cloudflare DNS + TLS)

Cloud Scheduler
  └── lease-manager-trigger-clear-solid-queue-jobs (12 * * * *)
        └── lease-manager-job-clear-solid-queue-jobs (Cloud Run Job)

VPC Network
  └── Serverless VPC Access Connector → Cloud SQL (private IP)

GCS Bucket
  └── lease-manager-production-uploads (ActiveStorage)
```

## Prerequisites

- [`gcloud` CLI](https://cloud.google.com/sdk/docs/install) installed and authenticated
- [`tofu` (OpenTofu)](https://opentofu.org/docs/intro/install/) >= 1.9 installed
- GCP billing account ID
- `config/master.key` from the existing Rails credentials (includes Google OAuth credentials)

---

## Step 0 — Configure gcloud

```bash
gcloud config configurations create lease-manager
gcloud config set project lease-manager-production
gcloud config set compute/region asia-south1
gcloud auth login
gcloud auth application-default login
```

---

## Step 1 — Create GCP Project (Manual, one-time)

```bash
gcloud projects create lease-manager-production --name="Lease Manager"
gcloud billing projects link lease-manager-production \
  --billing-account=BILLING_ACCOUNT_ID
```

---

## Step 2 — Bootstrap Tofu State Bucket (Manual, one-time)

This is the only resource not managed by Tofu (chicken-and-egg problem).

```bash
gcloud storage buckets create gs://lease-manager-tofu-state \
  --project=lease-manager-production \
  --location=asia-south1 \
  --uniform-bucket-level-access

gcloud storage buckets update gs://lease-manager-tofu-state --versioning
```

---

## Step 3 — Apply Infrastructure

```bash
cd infra
tofu init
tofu plan \
  -var project_id=lease-manager-production \
  -var region=asia-south1 \
  -var image_tag=placeholder
tofu apply \
  -var project_id=lease-manager-production \
  -var region=asia-south1 \
  -var image_tag=placeholder
```

> First apply takes ~10–15 minutes (Cloud SQL provisioning).

---

## Step 4 — Configure Secrets (Manual, one-time)

After `tofu apply` creates the secret resources, populate the manually-managed secrets:

```bash
# Rails master key (encrypts credentials including Google OAuth client ID/secret)
echo -n "$(cat config/master.key)" | \
  gcloud secrets versions add rails-master-key --data-file=-
```

`database-url` is fully Tofu-managed — no manual action needed.

> **Note:** Google OAuth credentials (client ID + secret) are stored in Rails encrypted credentials, decrypted at boot via `RAILS_MASTER_KEY`. They no longer need separate Secret Manager entries.

---

## Step 5 — Configure GitHub Actions Variables

After `tofu apply`, retrieve outputs and set as GitHub Actions repository variables
(Settings → Secrets and variables → Actions → Variables):

```bash
cd infra
tofu output wif_provider        # → WIF_PROVIDER
tofu output cicd_service_account # → CICD_SERVICE_ACCOUNT
```

| Variable | Value |
|---|---|
| `GCP_PROJECT_ID` | `lease-manager-production` |
| `GCP_REGION` | `asia-south1` |
| `WIF_PROVIDER` | Output from `tofu output wif_provider` |
| `CICD_SERVICE_ACCOUNT` | Output from `tofu output cicd_service_account` |

---

## Step 6 — Configure DNS (Cloudflare, Manual)

Cloud Run domain mappings are not supported in `asia-south1`. Instead, use a Cloudflare CNAME proxy to route traffic to the Cloud Run service URL.

1. Get the Cloud Run service URL:

```bash
tofu -chdir=infra output service_url
# e.g. https://lease-manager-xxxxxxxxxx-el.a.run.app
```

2. In the [Cloudflare dashboard](https://dash.cloudflare.com) for `loonyb.in`, add a CNAME record:

| Type | Name | Target | Proxy |
|---|---|---|---|
| CNAME | `lease-manager` | `lease-manager-xxxxxxxxxx-el.a.run.app` | Proxied (orange cloud) |

3. **TLS** is handled end-to-end automatically:
   - **Edge (client → Cloudflare)**: Cloudflare provisions and manages the TLS certificate for `lease-manager.loonyb.in`.
   - **Origin (Cloudflare → Cloud Run)**: Cloudflare connects to the `*.run.app` URL over HTTPS using Google's auto-managed certificate.
   - Set Cloudflare SSL/TLS mode to **Full (strict)** since Cloud Run has a valid Google-issued certificate.

No load balancer or Google-managed certificate is needed.

---

## Step 7 — Update OAuth Redirect URIs (Manual)

In the [Google Cloud Console OAuth app](https://console.cloud.google.com/apis/credentials):

- **Authorised JavaScript origin**: `https://lease-manager.loonyb.in`
- **Authorised redirect URI**: `https://lease-manager.loonyb.in/auth/google_oauth2/callback`

---

## Step 8 — First Deploy

Push to `main` or manually trigger the deploy workflow. It will:

1. Build and push the Docker image tagged with the git SHA
2. Run `tofu apply` (no-op on clean infra)
3. Execute the `lease-manager-migrate` Cloud Run Job
4. Deploy the Cloud Run revision
5. Run a smoke test against `/up`

Cloud Scheduler jobs become active immediately after `tofu apply`.

---

## Recurring Jobs

Recurring tasks are triggered by Cloud Scheduler → Cloud Run Jobs. They are not dependent on the web service being up.

| Job | Schedule | Description |
|---|---|---|
| `lease-manager-job-clear-solid-queue-jobs` | `12 * * * *` | Clears finished SolidQueue jobs |

### Manually trigger a job

```bash
gcloud run jobs execute lease-manager-job-clear-solid-queue-jobs \
  --region=asia-south1 --wait
```

### Pause a scheduled job without destroying it

```bash
gcloud scheduler jobs pause lease-manager-trigger-clear-solid-queue-jobs \
  --location=asia-south1
```

### Resume a paused job

```bash
gcloud scheduler jobs resume lease-manager-trigger-clear-solid-queue-jobs \
  --location=asia-south1
```

---

## Disaster Recovery

### Database backup and restore

Cloud SQL has automated daily backups with PITR enabled (7-day retention).

```bash
# List available backups
gcloud sql backups list --instance=lease-manager-production-db

# Restore from a backup
gcloud sql instances restore-backup lease-manager-production-db \
  --backup-id=BACKUP_ID
```

### Complete infrastructure rebuild

```bash
# Recreates all GCP resources except the state bucket and manually-configured secrets
cd infra
tofu init
tofu apply \
  -var project_id=lease-manager-production \
  -var region=asia-south1 \
  -var image_tag=LATEST_SHA
```

Then re-run Step 4 to restore manually-managed secrets from your secure vault.

**Complete rebuild time**: ~15–20 minutes.

---

## Secret Rotation

```bash
# Example: rotate the Rails master key
echo -n "NEW_MASTER_KEY" | \
  gcloud secrets versions add rails-master-key --data-file=-

# Redeploy to pick up the new version (push to main or trigger workflow)
```

---

## Logs

```bash
# Web service logs
gcloud run services logs read lease-manager \
  --region=asia-south1 --limit=100

# Migration job logs
gcloud run jobs executions list --job=lease-manager-migrate --region=asia-south1
```

---

## Follow-up Hardening (tracked separately)

- Cloud Monitoring alerts for error rates, latency, and instance count
- IAM audit: principle of least privilege review of all service account roles
- Cloud Monitoring uptime check on `/up`
- Log-based metrics and error rate dashboards
