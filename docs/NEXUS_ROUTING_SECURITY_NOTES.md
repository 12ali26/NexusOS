# Nexus Routing and Security Notes

## Current Issue

The dashboard and installed web apps may use separate host ports:

- CasaOS dashboard: port `80`
- Brave or Kasm browser app: port `6901`
- code-server: often port `8080`
- Chromium apps: often ports `3000` or `3001`

This works technically, but it is confusing for non-technical users and easy to
configure insecurely.

## Future Routing Direction

Introduce a reverse proxy layer later using Nginx, Caddy, Traefik, or Nginx Proxy
Manager. Prefer friendly subdomains such as:

- `computer.example.com`
- `browser.example.com`
- `code.example.com`
- `files.example.com`

Path-style routes such as `/browser`, `/code`, and `/files` are another option,
but only when the target applications support running below a path prefix.

## Security Defaults

Do not expose every application port publicly by default. For testing, prefer
source IP restrictions. For production, add HTTPS, authentication, and a reverse
proxy before publishing application routes. This milestone documents the
direction only; it does not change networking or firewall behavior.
