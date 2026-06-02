# Nexus Desktop Standalone Installer

The standalone Nexus Desktop installer starts the experimental browser desktop
on a server that already has Docker and the Docker Compose plugin installed. It
does not modify the main Nexus Cloud installer, CasaOS backend, or dashboard UI.

## Run the Installer

From a NexusOS repository checkout:

```sh
sudo bash scripts/install-desktop.sh
```

The standalone installer defaults to the stock desktop. Install Developer
Edition from a repository checkout with:

```sh
sudo bash scripts/install-desktop.sh --desktop-edition developer
```

On a fresh server, the main Nexus Cloud installer can run this standalone
installer after deploying the dashboard:

```sh
curl -fsSL https://raw.githubusercontent.com/12ali26/NexusOS/main/scripts/install-nexus.sh | sudo bash -s -- --with-desktop
```

To install the dashboard and Developer Edition together:

```sh
curl -fsSL https://raw.githubusercontent.com/12ali26/NexusOS/main/scripts/install-nexus.sh | sudo bash -s -- --with-desktop --desktop-edition developer
```

The script:

1. Confirms that Docker, the Docker Compose plugin, and
   `desktop/docker-compose.yml` are available.
2. Creates `/DATA/Nexus/Home`, `/DATA/Nexus/Workspace`,
   `/DATA/Nexus/Downloads`, and `/DATA/Nexus/Shared`.
3. Sets `/DATA/Nexus` ownership to `1000:1000`.
4. Creates the external Docker network `nexus-network` when it is missing.
5. Runs the stock Compose service by default. Developer Edition builds the
   local `nexus-desktop-developer:7b` image and recreates the service with the
   premium override.
6. Prints local desktop access URLs.

Streamed Developer Edition installs stage the Compose files, Dockerfile,
scripts, assets, and XFCE menu configuration before building. The build takes
longer than stock startup and requires network access to Ubuntu packages and
the signed VSCodium repository.

## Open the Desktop

Open TCP port `6901` in the server firewall or cloud security group for your IP
address, then visit:

```text
https://YOUR_SERVER_IP:6901
```

The Webtop prototype uses a self-signed HTTPS certificate. Your browser may show
a certificate warning during testing.

## Files and Reruns

Files persist under:

```text
/DATA/Nexus/Home
/DATA/Nexus/Workspace
/DATA/Nexus/Downloads
/DATA/Nexus/Shared
```

The script is safe to run again. Existing folders and the existing
`nexus-network` are reused, and Docker Compose reconciles the desktop container.

Return to stock without deleting persisted files:

```sh
sudo bash scripts/install-desktop.sh --desktop-edition stock
cd desktop
docker compose -f docker-compose.yml up -d --force-recreate
```

## Current Boundaries

- Docker must already be installed.
- Developer Edition supports `amd64` and `arm64`. Use stock desktop on `armv7`.
- There is no reverse proxy, trusted HTTPS certificate, dashboard card, or
  single sign-on yet.
