# Nexus Reverse Proxy Prototype

This directory contains a non-invasive Caddy prototype for testing a single
entrypoint in front of the Nexus Cloud dashboard and Nexus Desktop. It does not
replace the working dashboard on port `80` or the direct desktop URL on port
`6901`.

## Routes

| Test URL | Upstream |
| --- | --- |
| `https://SERVER_IP:8088/` | CasaOS dashboard on host port `80` |
| `https://SERVER_IP:8088/desktop/` | Nexus Desktop on `nexus-desktop:3001` |

Caddy joins the existing external Docker network `nexus-network`. Dashboard
requests use Docker's `host-gateway` mapping to reach CasaOS on the server.
Desktop requests use the `nexus-desktop` container directly over Webtop HTTPS.

## Start the Prototype

Nexus Desktop must already be running and `nexus-network` must already exist.
From the repository root:

```sh
cd proxy
docker compose up -d
```

Open TCP port `8088` for your IP address only, then test:

```text
https://YOUR_SERVER_IP:8088/
https://YOUR_SERVER_IP:8088/desktop/
```

Inspect status and logs:

```sh
docker compose ps
docker compose logs --tail=100
```

## Stop the Prototype

```sh
cd proxy
docker compose down
```

Stopping the prototype leaves the working dashboard and direct Nexus Desktop
access unchanged:

```text
http://YOUR_SERVER_IP
https://YOUR_SERVER_IP:6901
```

## Known Risks

- This is an HTTPS test entrypoint on port `8088` using Caddy's internal
  certificate authority. It does not provide browser-trusted public HTTPS, so
  expect a certificate warning during testing.
- Webtop uses a self-signed certificate. The prototype disables TLS certificate
  verification only for the private Caddy-to-Webtop connection. Do not carry
  this shortcut into production.
- Caddy proxies WebSocket upgrades automatically, but Webtop may still assume it
  is mounted at `/`. The `/desktop/` route strips its prefix before proxying.
  Browser assets, redirects, or WebSocket endpoints may reveal path-routing
  incompatibilities during testing.
- If path routing is unreliable, prefer a dedicated desktop subdomain such as
  `desktop.example.com`.
- Do not close port `6901` during this prototype milestone. It remains the
  working desktop fallback.
