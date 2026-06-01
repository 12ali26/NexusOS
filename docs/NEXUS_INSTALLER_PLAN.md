# Nexus Installer Plan

## Experimental Milestone

The installer is a portable Linux bootstrap for deploying a prebuilt Nexus Cloud
frontend archive over a CasaOS installation. It is intentionally simple and
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
4. Download the latest stable Nexus UI GitHub Release assets, verify the SHA256
   checksum, and extract the static frontend.
5. Create a timestamped backup of `/var/lib/casaos/www`, deploy the UI, record
   release metadata under `/var/lib/nexus-cloud`, restart `casaos.service`, and
   print possible local URLs.

CasaOS remains a set of host services. Docker remains available for applications
managed by CasaOS. The Nexus Cloud overlay is a static UI archive and does not
need Node.js, pnpm, or a source checkout during normal installation.

## Developer Source Builds

Developers can explicitly build the UI on the target machine:

```sh
sudo bash install-nexus.sh --build-from-source
```

This opt-in path clones or fast-forwards `/opt/nexusos`, installs Git, Node.js 22
LTS, Corepack, and `pnpm@9.0.6`, then compiles the Vue frontend. Archive failures
never fall back to this slower path automatically.

## Guardrails

The installer does not rename CasaOS-compatible services or data paths. It does
not assume a public IP, open firewall ports, install default apps, or configure a
reverse proxy.

## Later Milestones

- Publish a stable `get.nexuscloud.example` distribution endpoint.
- Add HTTPS, authentication, and reverse-proxy automation.
- Register a curated Nexus App Store source.
- Add optional setup profiles and default application bundles.
