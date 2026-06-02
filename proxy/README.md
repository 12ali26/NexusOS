# Nexus Reverse Proxy Plan

This directory contains a reference Caddy configuration for a future
subdomain-based proxy. It is not required for the current Nexus Cloud prototype.
Do not run it on an IP-only server unless you understand the DNS, certificate,
and port-mapping changes needed for your environment.

## Current Stable Access

Use the direct URLs during EC2 and IP-only development:

```text
http://SERVER_IP
https://SERVER_IP:6901
```

The first URL opens the Nexus Cloud dashboard. The second opens Nexus Desktop
directly through Webtop's published HTTPS port. Keep port `6901` restricted to
trusted tester IP addresses.

## Preferred Production Direction

Use separate DNS names so Webtop can remain mounted at `/`:

| Public URL | Upstream |
| --- | --- |
| `https://dashboard.example.com` | CasaOS dashboard on host port `80` |
| `https://desktop.example.com` | Nexus Desktop on `nexus-desktop:3001` |

The example [Caddyfile](./Caddyfile.prototype) assumes both names resolve to the
server and Caddy can obtain browser-trusted certificates. It is a planning
example, not a ready-to-run IP-only deployment.

## Why Path Routing Is Retired

The `/desktop/` experiment is currently not recommended. Webtop and noVNC use
secure browser APIs, WebSockets, redirects, and asset paths that are fragile
behind a rewritten prefix. Testing also exposed HTTP-versus-HTTPS upstream
mismatches. A dedicated desktop subdomain avoids prefix rewriting.

## Roll Back an Experiment

If a proxy container is running from earlier testing, remove it with:

```sh
cd proxy
docker compose down
```

This does not stop CasaOS or Nexus Desktop. The direct URLs remain available.

## Notes

- Caddy joins the external Docker network `nexus-network`.
- Dashboard traffic reaches CasaOS through Docker's `host-gateway` mapping.
- Desktop traffic uses Webtop's internal HTTPS port `3001`.
- The example disables certificate verification only for the private
  Caddy-to-Webtop hop because Webtop uses a self-signed certificate.
- Production deployment still needs real DNS, trusted HTTPS, firewall policy,
  and a reviewed port-publishing layout.
