terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }
}

resource "cloudflare_workers_script" "proxy" {
  account_id = var.cloudflare_account_id
  script_name = "lease-manager-proxy"

  content = <<-JS
    const ORIGIN = "${var.cloud_run_host}";

    export default {
      async fetch(request) {
        const url = new URL(request.url);
        const originalHost = url.hostname;
        url.hostname = ORIGIN;
        url.protocol = "https:";

        const headers = new Headers(request.headers);
        headers.set("Host", ORIGIN);
        headers.set("X-Forwarded-Host", originalHost);

        return fetch(url.toString(), {
          method: request.method,
          headers,
          body: request.body,
          redirect: "manual",
        });
      },
    };
  JS

  compatibility_date = "2025-01-01"
  main_module        = "worker.js"
}

resource "cloudflare_dns_record" "lease_manager" {
  zone_id = var.cloudflare_zone_id
  name    = "lease-manager"
  type    = "CNAME"
  content = var.cloud_run_host
  proxied = true
  ttl     = 1
  comment = "Proxied via Cloudflare Worker to Cloud Run"
}

resource "cloudflare_workers_route" "proxy" {
  zone_id = var.cloudflare_zone_id
  pattern = "lease-manager.loonyb.in/*"
  script  = cloudflare_workers_script.proxy.script_name
}
