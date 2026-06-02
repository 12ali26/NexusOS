# Experimental Nexus Cloud Installer

The Nexus Cloud installer deploys the branded frontend over CasaOS while keeping
CasaOS services, APIs, and storage paths intact. It is experimental and should
first be used on a test server.

## Run the Installer

On a fresh supported Linux server, run:

```sh
curl -fsSL https://raw.githubusercontent.com/12ali26/NexusOS/main/scripts/install-nexus.sh | sudo bash
```

This installs the Nexus Cloud dashboard and core services only.

To install the dashboard and optional Nexus Desktop container together, run:

```sh
curl -fsSL https://raw.githubusercontent.com/12ali26/NexusOS/main/scripts/install-nexus.sh | sudo bash -s -- --with-desktop
```

The installer downloads a verified prebuilt Nexus Cloud UI archive, installs
Docker and CasaOS when needed, deploys the static frontend, and prints possible
local access URLs. It does not assume that the server has a public IP.

## What It Changes

- Installs `curl`, `ca-certificates`, `rsync`, and `tar`.
- Installs Docker with Docker's convenience script when Docker is missing.
- Installs CasaOS with the official CasaOS installer when CasaOS is missing.
- Downloads `nexus-ui.tar.gz` and its SHA256 checksum from the latest stable
  Nexus UI GitHub Release.
- Verifies and extracts the archive before replacing `/var/lib/casaos/www`.
- Records the deployed release tag and checksum under `/var/lib/nexus-cloud`.
- Restarts the existing `casaos.service`.

The installer does not rename backend services, install default apps, configure
a reverse proxy, or open firewall ports.

When `--with-desktop` is passed, the installer runs the standalone Nexus Desktop
installer after the dashboard UI deploys successfully. It creates the persistent
`/DATA/Nexus` folders, creates or reuses `nexus-network`, and starts the Webtop
container. The default dashboard-only behavior remains unchanged.

CasaOS itself runs as host services. Docker is used for applications managed by
CasaOS. The Nexus Cloud overlay is a static frontend archive, so normal installs
do not need Git, Node.js, Corepack, pnpm, or a frontend build on the server.

## Versions and Developer Builds

Deploy a specific release for testing or rollback:

```sh
curl -fsSL https://raw.githubusercontent.com/12ali26/NexusOS/main/scripts/install-nexus.sh | sudo bash -s -- --version nexus-ui-v0.1.0
```

Developers can opt into the slower source-build path:

```sh
curl -fsSL https://raw.githubusercontent.com/12ali26/NexusOS/main/scripts/install-nexus.sh | sudo bash -s -- --build-from-source
```

Source mode clones or fast-forwards `/opt/nexusos`, installs Git and Node.js 22
LTS when needed, activates `pnpm@9.0.6`, and builds the Vue frontend locally.
Archive download failures do not automatically fall back to source mode.

## Publish a UI Release

The dedicated GitHub Actions workflow builds and publishes UI assets for tags
matching `nexus-ui-v*.*.*`. Publish the first experimental stable-channel asset
with:

```sh
git tag nexus-ui-v0.1.0
git push origin nexus-ui-v0.1.0
```

The workflow publishes `nexus-ui.tar.gz` and `nexus-ui.tar.gz.sha256`. Normal
installs fail clearly until at least one stable-channel UI release exists.

## Restore the Previous UI

Each deployment prints a timestamped backup folder using the format
`www.backup-YYYYMMDDTHHMMSSZ`, for example:

```text
/var/lib/casaos/www.backup-20260601T120000Z
```

Restore that backup with:

```sh
sudo rsync -a --delete /var/lib/casaos/www.backup-20260601T120000Z/ /var/lib/casaos/www/
sudo chown -R root:root /var/lib/casaos/www
sudo find /var/lib/casaos/www -type d -exec chmod 755 {} +
sudo find /var/lib/casaos/www -type f -exec chmod 644 {} +
sudo systemctl restart casaos
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

When Nexus Desktop is enabled, also open TCP port `6901` only for your own IP
address. Visit `https://YOUR_SERVER_IP:6901` and expect a self-signed certificate
warning during the prototype milestone.

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
- Existing tracked changes in `/opt/nexusos` stop developer source-build updates
  rather than being overwritten.

Expose only the dashboard and application ports you intentionally need. Restrict
test deployments by source IP whenever the hosting environment supports it.
