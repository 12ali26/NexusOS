# Experimental Nexus Cloud Installer

The Nexus Cloud installer deploys the branded frontend over CasaOS while keeping
CasaOS services, APIs, and storage paths intact. It is experimental and should
first be used on a test server.

## Run the Installer

On a fresh supported Linux server, run:

```sh
curl -fsSL https://raw.githubusercontent.com/12ali26/NexusOS/main/scripts/install-nexus.sh | sudo bash
```

The installer clones the repository into `/opt/nexusos`, installs missing
dependencies, installs Docker and CasaOS when needed, builds the frontend, and
prints possible local access URLs. It does not assume that the server has a
public IP.

## What It Changes

- Installs `curl`, `git`, `ca-certificates`, and `rsync`.
- Installs Docker with Docker's convenience script when Docker is missing.
- Installs CasaOS with the official CasaOS installer when CasaOS is missing.
- Installs Node.js 22 LTS when an older Node.js runtime is present or Node.js is
  missing, then enables Corepack and activates `pnpm@9.0.6`.
- Clones or fast-forwards the `main` branch in `/opt/nexusos`.
- Builds the frontend and replaces `/var/lib/casaos/www`.
- Restarts the existing `casaos.service`.

The installer does not rename backend services, install default apps, configure
a reverse proxy, or open firewall ports.

## Restore the Previous UI

Each deployment prints a timestamped backup path such as:

```text
/var/lib/casaos/www.backup-20260601T120000Z
```

Restore that backup with:

```sh
sudo rsync -a --delete /var/lib/casaos/www.backup-20260601T120000Z/ /var/lib/casaos/www/
sudo systemctl restart casaos.service
```

Use the exact backup path printed by your installer run.

## Platforms

Test the first working path on:

- Ubuntu Server
- Debian
- Raspberry Pi OS through the Debian-family package path

The installer also includes experimental, unvalidated dependency handling for:

- CentOS
- RHEL
- Fedora

Other Linux distributions stop with an unsupported-distribution message. CPU
architectures `amd64`, `arm64`, and `armv7` are recognized. Other architectures
produce an experimental warning and may fail in upstream installers or package
repositories.

## Environment Notes

### VPS

Open the CasaOS dashboard port, usually port `80`, in the provider firewall or
security group only when remote access is needed. The installer prints local
addresses and does not attempt to discover a public address.

### Home Server

Use the printed LAN address from another device on the same network. Avoid router
port forwarding until HTTPS and authentication have been planned.

### Raspberry Pi and ARM

Prefer a current Raspberry Pi OS release. The installer recognizes `arm64` and
`armv7`, but available packages and upstream CasaOS components still depend on
the selected OS image.

### Windows and WSL2

Run Nexus Cloud on a Linux server when possible. WSL2 is not a tested deployment
target because systemd, Docker networking, and LAN access can differ from a
normal Linux host.

### Proxmox

Prefer a Linux virtual machine for the first tests. An LXC container may require
additional nesting, cgroup, systemd, and Docker configuration and is not yet a
validated target.

## Known Limitations and Security

- There is no automatic HTTPS, reverse proxy, or extra authentication layer.
- Installed apps may publish their own host ports.
- The installer does not automatically update firewall rules.
- The RHEL-family path is best effort and has not been validated.
- Existing tracked changes in `/opt/nexusos` stop updates rather than being
  overwritten.

Expose only the dashboard and application ports you intentionally need. Restrict
test deployments by source IP whenever the hosting environment supports it.
