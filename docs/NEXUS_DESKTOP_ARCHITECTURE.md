# Nexus Desktop Architecture

## Milestone Status

Nexus Desktop is a working experimental browser desktop for Nexus Cloud. The
prototype was validated on an EC2 Linux server using:

```text
lscr.io/linuxserver/webtop:ubuntu-xfce
```

The desktop opened in a browser over HTTPS on host port `6901`. The XFCE file
manager worked, the mounted Nexus folders appeared inside the desktop, and a
file created in the workspace persisted after the container restarted.

## Why Nexus Desktop Exists

CasaOS apps are useful independent Docker services. Each app commonly opens as
its own browser page and may expose its own port, filesystem view, and
authentication flow.

Nexus Desktop adds a persistent browser-accessible Linux workspace above that
model. It gives users one desktop session and one shared filesystem location for
files, downloads, and future desktop tools. This addresses the disconnected
app/filesystem problem: files created or downloaded in the desktop remain
available through stable server-side folders instead of being isolated inside
an ephemeral container layer.

Nexus Desktop does not replace CasaOS apps. It complements them:

| Capability | CasaOS App Containers | Nexus Desktop |
| --- | --- | --- |
| Primary role | Run individual services | Provide one interactive Linux workspace |
| Typical access | Separate app URL and port | Browser desktop over HTTPS |
| Filesystem | App-specific mounts | Shared Nexus folders |
| Current integration | Managed by CasaOS | Compose prototype managed manually |

## Current Architecture

```text
Browser
  -> HTTPS on host port 6901
  -> linuxserver/webtop:ubuntu-xfce
  -> XFCE desktop and file manager
  -> persistent server folders under /DATA/Nexus
```

The Compose prototype joins the external Docker network `nexus-network`. This
network is the starting point for later communication with shared Nexus apps and
services. There is no Go backend integration yet.

## Persistent Folders

| Server path | Desktop container path | Purpose |
| --- | --- | --- |
| `/DATA/Nexus/Home` | `/config` | Persistent Webtop home and configuration |
| `/DATA/Nexus/Workspace` | `/config/Workspace` | User workspace files |
| `/DATA/Nexus/Downloads` | `/config/Downloads` | Downloaded files |
| `/DATA/Nexus/Shared` | `/config/Shared` | Files shared with future apps and services |

## Validated Behavior

The EC2 prototype test confirmed:

- Nexus Desktop opens in a browser at `https://SERVER_IP:6901`.
- The Webtop XFCE desktop and file manager load successfully.
- `/config/Workspace`, `/config/Downloads`, and `/config/Shared` are visible
  inside the desktop.
- Files created in `/config/Workspace` survive a container restart.

## Current Limitations

- Port `6901` must be opened manually in the host firewall or EC2 security
  group.
- Webtop currently uses its default self-signed HTTPS certificate, so browsers
  display a certificate warning.
- There is no Nginx or Caddy reverse proxy yet.
- The Nexus installer provisions the desktop only when `--with-desktop` is
  passed.
- The Nexus dashboard does not expose a Nexus Desktop app card yet.
- Nexus Cloud and Nexus Desktop do not share single sign-on yet.

Restrict port `6901` to trusted source IP addresses during testing.

## Future Plan

1. Keep the optional `--with-desktop` installer path small and explicit while
   the prototype matures.
2. Add a Nexus Desktop card in the Nexus dashboard.
3. Add Nginx or Caddy reverse-proxy routing with domain and trusted HTTPS
   support.
4. Use `nexus-network` as a shared app and service network where isolation rules
   allow it.
5. Explore a Kubernetes or cluster edition after the single-server desktop
   architecture is stable.
