# Nexus Desktop Prototype

Nexus Desktop is an experimental browser-accessible Linux desktop for Nexus
Cloud. It runs the LinuxServer.io Webtop Ubuntu XFCE image as an isolated Docker
Compose service. It is not integrated with the Nexus Cloud Go backend yet.

## Default Port

The Webtop container listens for HTTPS traffic on port `3001`. This prototype
publishes it on host port `6901`, so open:

```text
https://YOUR_SERVER_IP:6901
```

## Start on EC2 or Another Linux Server

Install Docker and the Docker Compose plugin first. On a Nexus Cloud server, the
experimental Nexus installer normally installs Docker already.

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

## Known Limitations

- This prototype is not connected to the Nexus Cloud dashboard or Go backend.
- Port `6901` exposes Webtop HTTPS directly using its default self-signed
  certificate. Restrict the EC2 security-group rule to your own IP during
  testing and expect a browser certificate warning.
- HTTPS, reverse-proxy routing, Nexus authentication, and automatic app
  installation are intentionally deferred.
- The container uses the upstream Ubuntu XFCE image without extra development
  tools or a custom Nexus desktop theme.
