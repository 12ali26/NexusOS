# Nexus Desktop Standalone Installer

The standalone Nexus Desktop installer starts the experimental browser desktop
on a server that already has Docker and the Docker Compose plugin installed. It
does not modify the main Nexus Cloud installer, CasaOS backend, or dashboard UI.

## Run the Installer

From a NexusOS repository checkout:

```sh
sudo bash scripts/install-desktop.sh
```

The script:

1. Confirms that Docker, the Docker Compose plugin, and
   `desktop/docker-compose.yml` are available.
2. Creates `/DATA/Nexus/Home`, `/DATA/Nexus/Workspace`,
   `/DATA/Nexus/Downloads`, and `/DATA/Nexus/Shared`.
3. Sets `/DATA/Nexus` ownership to `1000:1000`.
4. Creates the external Docker network `nexus-network` when it is missing.
5. Runs `docker compose up -d` from `desktop/`.
6. Prints local desktop access URLs.

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

## Current Boundaries

- Docker must already be installed.
- The main Nexus Cloud installer does not call this script yet.
- There is no reverse proxy, trusted HTTPS certificate, dashboard card, or
  single sign-on yet.
