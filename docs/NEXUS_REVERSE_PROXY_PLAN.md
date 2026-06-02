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

Any proxy experiment must remain non-invasive. CasaOS continues serving the
dashboard on port `80`, and Nexus Desktop remains directly available on port
`6901`.

## Proxy Comparison

| Proxy | Strengths for Nexus | Tradeoffs |
| --- | --- | --- |
| Caddy | Small readable config, straightforward reverse proxying, automatic HTTPS later | Less familiar than Nginx to some operators |
| Nginx | Industry standard, powerful routing controls, broad operational knowledge | More manual configuration for certificates and common proxy details |
| Traefik | Docker-native service discovery, useful for a later app-heavy or clustered edition | More moving pieces and configuration complexity for the first prototype |

Use **Caddy** for the prototype. It keeps the experiment compact while leaving a
clear path to domain-based automatic HTTPS later.

## Routing Options

### Option A: Path Routing (Experimental, Not Recommended)

```text
https://SERVER_IP:8088/
https://SERVER_IP:8088/desktop/
```

The retired experiment used this model. Caddy proxied `/` to CasaOS and stripped
the `/desktop` prefix before proxying desktop traffic to Webtop.

Path routing gives users one host entrypoint, but it only works reliably when
the upstream application tolerates a path prefix or rewrite. Webtop and noVNC
use secure browser APIs, WebSockets, redirects, and asset paths that are fragile
behind a rewritten prefix. Testing also exposed HTTP-versus-HTTPS upstream
mismatches. Do not continue using this as the recommended prototype.

### Option B: Subdomain Routing (Preferred)

```text
https://dashboard.example.com
https://desktop.example.com
```

Use subdomains for the production direction:

```text
dashboard.example.com -> CasaOS/Nexus dashboard
desktop.example.com   -> nexus-desktop
```

A dedicated desktop subdomain is simpler for noVNC-style applications because
Webtop can keep running at `/` without path rewriting. This requires a real
domain or local DNS mapping so the browser sends the expected hostname.

## WebSocket and noVNC Considerations

Webtop's browser desktop relies on long-lived WebSocket connections. The proxy
must preserve HTTP upgrade behavior, including the `Upgrade` and `Connection`
headers. Caddy's `reverse_proxy` supports WebSocket upgrades automatically.

The subdomain example proxies Webtop at `https://nexus-desktop:3001`. Webtop
currently uses a self-signed certificate, so the reference config uses
`tls_insecure_skip_verify` only for the private Caddy-to-Webtop hop. That option
disables certificate verification and must not become a production default.

For production, prefer a trusted upstream relationship or proxy to a suitable
private plaintext endpoint if Webtop supports it. Keep direct port `6901` access
available until proxied desktop behavior is proven.

## Preferred Proxy Architecture

```text
Browser
  -> trusted HTTPS for dashboard.example.com or desktop.example.com
  -> Caddy container on nexus-network
     -> dashboard.example.com -> host.docker.internal:80 -> CasaOS dashboard
     -> desktop.example.com   -> nexus-desktop:3001      -> Webtop HTTPS and XFCE
```

Prototype files:

```text
proxy/Caddyfile.prototype
proxy/docker-compose.yml
proxy/README.md
```

The Compose scaffold joins external Docker network `nexus-network` and uses
Docker's `host-gateway` mapping for the CasaOS host service. Its publishing
layout must be reviewed before a domain-based deployment.

## Current EC2 and IP-Only Testing

Do not require a reverse proxy for current server testing. Use:

```text
dashboard: http://SERVER_IP
desktop:   https://SERVER_IP:6901
```

If an earlier proxy experiment is still running, stop it with:

```sh
cd proxy
docker compose down
```

## Future Direction

- Add real DNS names such as `dashboard.example.com` and
  `desktop.example.com`.
- Let Caddy manage trusted HTTPS certificates when DNS and firewall policy are
  ready.
- Review the Compose port-publishing layout before deploying the domain-based
  proxy.
- Add authentication and single sign-on before exposing hosted deployments.
- Evaluate Traefik again for a later Docker-heavy or Kubernetes/cluster edition.
