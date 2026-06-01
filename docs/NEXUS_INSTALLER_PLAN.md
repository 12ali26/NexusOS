# Nexus Installer Plan

## Experimental Milestone

The first installer is a portable Linux bootstrap for deploying the Nexus Cloud
frontend over an existing CasaOS installation. It is intentionally simple and
readable while the installation flow is tested.

```sh
curl -fsSL https://raw.githubusercontent.com/12ali26/NexusOS/main/scripts/install-nexus.sh | sudo bash
```

The first validated path is Ubuntu/Debian. Raspberry Pi OS uses the same
Debian-family path. CentOS, RHEL, and Fedora support is present as an experimental
best-effort path through `dnf` or `yum`.

## Current Behavior

1. Detect the distribution from `/etc/os-release` and the CPU architecture from
   `uname -m`.
2. Install the small set of bootstrap dependencies and Docker when missing.
3. Install CasaOS with its official installer when missing.
4. Clone or fast-forward `/opt/nexusos`, provision Node.js 22 LTS and
   `pnpm@9.0.6`, and build the UI.
5. Create a timestamped backup of `/var/lib/casaos/www`, deploy the Nexus Cloud
   UI, restart `casaos.service`, and print possible local URLs.

## Guardrails

The installer does not rename CasaOS-compatible services or data paths. It does
not assume a public IP, open firewall ports, install default apps, or configure a
reverse proxy.

## Later Milestones

- Publish a stable `get.nexuscloud.example` distribution endpoint.
- Add HTTPS, authentication, and reverse-proxy automation.
- Register a curated Nexus App Store source.
- Add optional setup profiles and default application bundles.
