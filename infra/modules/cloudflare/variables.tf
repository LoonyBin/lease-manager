variable "cloudflare_account_id" {
  description = "Cloudflare account ID"
  type        = string
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID for loonyb.in"
  type        = string
}

variable "cloud_run_host" {
  description = "Cloud Run service hostname (e.g. lease-manager-xxx.asia-south1.run.app)"
  type        = string
}
