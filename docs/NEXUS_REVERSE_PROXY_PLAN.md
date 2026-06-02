# Nexus Reverse Proxy Plan

## Why Add a Reverse Proxy

Nexus Cloud currently uses separate URLs:

```text
http://SERVER_IP
https://SERVER_IP:6901
```

A reverse proxy can hide service ports, reduce firewall exposure, simplify the
user experience, prepare for domain and HTTPS support, and provide a foundation
for a future hosted Nexus Cloud version.

The prototype must remain non-invasive. CasaOS continues serving the dashboard
on port `80`, Nexus Desktop remains directly available on port `6901`, and Caddy
listens on test port `8088`.

## Proxy Comparison

| Proxy | Strengths for Nexus | Tradeoffs |
| --- | --- | --- |
| Caddy | Small readable config, straightforward reverse proxying, automatic HTTPS later | Less familiar than Nginx to some operators |
| Nginx | Industry standard, powerful routing controls, broad operational knowledge | More manual configuration for certificates and common proxy details |
| Traefik | Docker-native service discovery, useful for a later app-heavy or clustered edition | More moving pieces and configuration complexity for the first prototype |

Use **Caddy** for the prototype. It keeps the experiment compact while leaving a
clear path to domain-based automatic HTTPS later.

## Routing Options

### Option A: Path Routing

```text
https://SERVER_IP:8088/
https://SERVER_IP:8088/desktop/
```

The prototype uses this model. Caddy proxies `/` to CasaOS and strips the
`/desktop` prefix before proxying desktop traffic to Webtop.

Path routing gives users one host entrypoint, but it only works reliably when
the upstream application tolerates a path prefix or rewrite. Webtop may emit
root-relative asset paths, redirects, or WebSocket URLs that escape `/desktop`.

### Option B: Subdomain Routing

```text
https://nexus.example.com
https://desktop.example.com
```

Use subdomains if Webtop path routing is unreliable. A dedicated desktop
subdomain is likely simpler for noVNC-style applications because Webtop can keep
running at `/` without path rewriting. This becomes the preferred production
direction if the `/desktop/` test reveals compatibility issues.

## WebSocket and noVNC Considerations

Webtop's browser desktop relies on long-lived WebSocket connections. The proxy
must preserve HTTP upgrade behavior, including the `Upgrade` and `Connection`
headers. Caddy's `reverse_proxy` supports WebSocket upgrades automatically.

The prototype proxies Webtop at `https://nexus-desktop:3001`. Webtop currently
uses a self-signed certificate, so the prototype uses
`tls_insecure_skip_verify` only for the private Caddy-to-Webtop hop. That option
disables certificate verification and must not become a production default.

For production, prefer a trusted upstream relationship or proxy to a suitable
private plaintext endpoint if Webtop supports it. Keep direct port `6901` access
available until proxied desktop behavior is proven.

## Prototype Architecture

```text
Browser
  -> HTTPS on host port 8088 using Caddy's internal certificate
  -> Caddy container on nexus-network
     -> /          -> host.docker.internal:80 -> CasaOS dashboard
     -> /desktop/* -> nexus-desktop:3001      -> Webtop HTTPS and XFCE
```

Prototype files:

```text
proxy/Caddyfile.prototype
proxy/docker-compose.yml
proxy/README.md
```

The Compose service joins external Docker network `nexus-network`, maps host
port `8088`, and uses Docker's `host-gateway` mapping for the CasaOS host
service.

## Prototype Test Plan

1. Keep the working CasaOS dashboard on port `80`.
2. Keep direct Nexus Desktop access on `https://SERVER_IP:6901`.
3. Start the proxy manually with `cd proxy && docker compose up -d`.
4. Open TCP port `8088` only for the tester's IP address.
5. Accept the prototype certificate warning and confirm
   `https://SERVER_IP:8088/` loads the dashboard.
6. Test `https://SERVER_IP:8088/desktop/`, including WebSocket-backed desktop
   interaction.
7. Stop the proxy with `cd proxy && docker compose down`.
8. Confirm the original port `80` dashboard and direct port `6901` desktop still
   work.
9. If desktop path routing fails, document subdomain routing as the preferred
   next implementation.

## Future Direction

- Move from test port `8088` to a production entrypoint only after validation.
- Add a domain such as `nexus.example.com`.
- Let Caddy manage trusted HTTPS certificates when DNS and firewall policy are
  ready.
- Prefer `desktop.example.com` if Webtop cannot reliably run below `/desktop/`.
- Add authentication and single sign-on before exposing hosted deployments.
- Evaluate Traefik again for a later Docker-heavy or Kubernetes/cluster edition.
