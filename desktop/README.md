# Nexus Desktop Prototype

Nexus Desktop is the first working browser-accessible Linux desktop for Nexus
Cloud. It runs the LinuxServer.io Webtop Ubuntu XFCE image as an isolated Docker
Compose service. It is not integrated with the Nexus Cloud Go backend yet.

Unlike separate CasaOS apps, Nexus Desktop provides one persistent visual
workspace with a file manager, desktop session, and shared Nexus folders. Apps
and files can meet in the same Linux environment instead of feeling like
disconnected browser tabs backed by unrelated containers.

The current prototype architecture is:

```text
Browser
  -> HTTPS on host port 6901
  -> linuxserver/webtop container
  -> XFCE desktop
  -> /DATA/Nexus persistent folders
```

See [NEXUS_DESKTOP_ARCHITECTURE.md](../docs/NEXUS_DESKTOP_ARCHITECTURE.md) for
the design direction.

## Default Port

The Webtop container listens for HTTPS traffic on port `3001`. This prototype
publishes it on host port `6901`, so open:

```text
https://YOUR_SERVER_IP:6901
```

## Start on EC2 or Another Linux Server

Install Docker and the Docker Compose plugin first. On a Nexus Cloud server, the
experimental Nexus installer normally installs Docker already.

### Standalone Install

From the NexusOS repository root, run:

```sh
sudo bash scripts/install-desktop.sh
```

The standalone script creates the folders, reuses or creates `nexus-network`,
starts the desktop with Docker Compose, and prints local access URLs. See
[NEXUS_DESKTOP_INSTALLER.md](../docs/NEXUS_DESKTOP_INSTALLER.md) for details.

### Manual Install

Create the persistent folders:

```sh
sudo mkdir -p \
  /DATA/Nexus/Home \
  /DATA/Nexus/Workspace \
  /DATA/Nexus/Downloads \
  /DATA/Nexus/Shared

sudo chown -R 1000:1000 /DATA/Nexus
```

Create the shared Docker network:

```sh
docker network inspect nexus-network >/dev/null 2>&1 ||
  docker network create nexus-network
```

The command reuses the network when it already exists.

Start the desktop:

```sh
cd desktop
docker compose up -d
```

Open TCP port `6901` in the EC2 security group for your IP address, then visit:

```text
https://YOUR_EC2_PUBLIC_IP:6901
```

To inspect container state:

```sh
docker compose ps
docker compose logs --tail=100
```

To stop the desktop without deleting persistent files:

```sh
docker compose down
```

## Configuration

The Compose file uses these environment variables:

| Variable | Default | Purpose |
| --- | --- | --- |
| `TZ` | `Etc/UTC` | Desktop timezone |
| `PUID` | `1000` | Linux UID used for persisted files |
| `PGID` | `1000` | Linux GID used for persisted files |
| `TITLE` | `Nexus Desktop` | Browser page title |

Override the optional defaults when starting the container:

```sh
TZ=America/New_York PUID=1000 PGID=1000 docker compose up -d
```

## Persistent Files

Desktop files survive container replacement because they are stored on the
server:

| Server path | Container path |
| --- | --- |
| `/DATA/Nexus/Home` | `/config` |
| `/DATA/Nexus/Workspace` | `/config/Workspace` |
| `/DATA/Nexus/Downloads` | `/config/Downloads` |
| `/DATA/Nexus/Shared` | `/config/Shared` |

## Validated Milestone

The prototype was tested successfully on an EC2 Linux server:

- The Nexus Desktop page opened in a browser over HTTPS on port `6901`.
- The XFCE desktop and file manager loaded.
- `/config/Workspace`, `/config/Downloads`, and `/config/Shared` appeared inside
  the desktop.
- A file created inside `/config/Workspace` remained available after restarting
  the container.

## Known Limitations

- This prototype is not connected to the Nexus Cloud dashboard or Go backend.
- Port `6901` must be opened manually in the EC2 security group or host
  firewall.
- Port `6901` exposes Webtop HTTPS directly using its default self-signed
  certificate. Restrict the EC2 security-group rule to your own IP during
  testing and expect a browser certificate warning.
- There is no reverse proxy, public domain, trusted HTTPS certificate, or Nexus
  single sign-on yet.
- The main Nexus Cloud installer does not call the standalone desktop installer
  yet.
- The Nexus dashboard does not have a Nexus Desktop card yet.
- The container uses the upstream Ubuntu XFCE image without extra development
  tools or a custom Nexus desktop theme.

## Future Direction

- Add an optional Nexus installer flag for desktop provisioning.
- Add a Nexus Desktop app card in the dashboard.
- Place the desktop behind Nginx or Caddy with domain and HTTPS support.
- Use `nexus-network` as the shared app and service network where appropriate.
- Explore a later Kubernetes or cluster edition after the single-server model is
  stable.
