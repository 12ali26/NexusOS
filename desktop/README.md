# Nexus Desktop Prototype

Nexus Desktop is a persistent browser-accessible Linux workspace for Nexus
Cloud. It runs LinuxServer Webtop Ubuntu XFCE as an isolated Docker Compose
service and keeps files under `/DATA/Nexus`.

```text
Browser
  -> HTTPS on host port 6901
  -> linuxserver/webtop container
  -> XFCE desktop
  -> /DATA/Nexus persistent folders
```

Open:

```text
https://YOUR_SERVER_IP:6901
```

Expect a self-signed certificate warning during this prototype milestone.
Restrict TCP port `6901` to trusted tester IP addresses.

## Persistent Folders

| Server path | Container path |
| --- | --- |
| `/DATA/Nexus/Home` | `/config` |
| `/DATA/Nexus/Workspace` | `/config/Workspace` |
| `/DATA/Nexus/Downloads` | `/config/Downloads` |
| `/DATA/Nexus/Shared` | `/config/Shared` |

Nexus Desktop was validated on EC2: the desktop and file manager opened, Nexus
folders appeared inside XFCE, and Workspace files survived a container restart.

## Stock Desktop

The base Compose file remains the stable fallback for streamed installs and
servers that do not need premium theming:

```sh
cd desktop
docker compose up -d
```

The standalone installer still uses this stock path:

```sh
sudo bash scripts/install-desktop.sh
```

## Premium Milestone 6B

Milestone 6B is an opt-in repository-checkout prototype. It adds:

- `Arc-Dark` GTK and XFWM styling.
- `Papirus-Dark` icons, Breeze cursors, and Inter UI fonts.
- A branded navy wallpaper with subtle mesh and orange glow.
- A single dark 48-pixel bottom taskbar with a Whisker application menu.
- Browser, Files, Terminal, Workspace, and Settings panel launchers.
- A dark terminal profile that opens in `/config/Workspace`.
- Thunar icon-view defaults and bookmarks for Home, Workspace, Downloads, and
  Shared.
- Workspace, Downloads, and Shared desktop folder shortcuts.
- A local Nexus Desktop browser welcome page with optional web links.

VS Code and VSCodium are not baked into the premium image, so the premium
profile does not create a fake editor launcher.

See [NEXUS_DESKTOP_UI_PLAN.md](./NEXUS_DESKTOP_UI_PLAN.md) for the visual design
and XFCE constraints.

### Build and Apply Premium Desktop

From a NexusOS repository checkout:

```sh
cd desktop
docker compose -f docker-compose.yml -f docker-compose.premium.yml build --pull nexus-desktop
docker compose -f docker-compose.yml -f docker-compose.premium.yml up -d --force-recreate
```

The premium image includes the theme hook and assets. No runtime package
installation is required.

### Force Reapply

The first premium startup upgrades an existing Milestone 6A profile once by
creating:

```text
/config/.nexus-desktop/theme-applied-v2
```

To back up the current visual profile and force a deterministic reapply:

```sh
docker exec nexus-desktop bash /custom-cont-init.d/apply-nexus-theme.sh --force
cd ~/NexusOS/desktop
docker compose -f docker-compose.yml -f docker-compose.premium.yml restart nexus-desktop
```

XFCE backups use:

```text
/config/.config/xfce4.backup-YYYYMMDDTHHMMSSZ
```

Existing GTK bookmarks are backed up separately. The script does not delete
user files, Workspace, Downloads, Shared, or Desktop documents.

## Validated Developer Workstation

Nexus Desktop was tested successfully as a browser-accessible developer
workstation on EC2:

- A VS Code `.deb` package was downloaded and installed inside the running
  desktop container.
- A PackageKit warning appeared during installation but did not block the
  install.
- VS Code launched successfully inside the browser desktop.
- `/config/Workspace` was opened in VS Code.
- A `test.js` file created in VS Code appeared on the EC2 host at:

```text
/DATA/Nexus/Workspace/test.js
```

The Compose bind mount provides the mapping:

```text
/config/Workspace -> /DATA/Nexus/Workspace
```

This proves that graphical development tools can run inside Nexus Desktop
while project files remain persistent and directly accessible on the host.

## Install Downloaded `.deb` Apps

Milestone 7A adds a repository-checkout helper for installing one downloaded
Debian package at a time. Recreate the stock or premium desktop container after
pulling changes so the read-only helper mount becomes available:

```sh
cd ~/NexusOS
git pull
cd desktop
docker compose up -d --force-recreate
```

For the premium desktop, use:

```sh
cd ~/NexusOS
git pull
cd desktop
docker compose -f docker-compose.yml -f docker-compose.premium.yml up -d --force-recreate
```

Install a downloaded VS Code package:

```sh
docker exec -it nexus-desktop bash /config/nexus/scripts/nexus-install-deb.sh '/config/Downloads/code_*.deb'
```

Install a downloaded Cursor package:

```sh
docker exec -it nexus-desktop bash /config/nexus/scripts/nexus-install-deb.sh '/config/Downloads/cursor_*.deb'
```

If `/config/Downloads` contains exactly one `.deb`, install it with:

```sh
docker exec -it nexus-desktop bash /config/nexus/scripts/nexus-install-downloaded-debs.sh
```

View the append-only installation log:

```sh
docker exec -it nexus-desktop tail -100 /config/nexus/logs/app-install.log
```

Keep wildcard patterns quoted so they are expanded inside the container. The
helper refuses zero matches and multiple matches. See
[NEXUS_DESKTOP_APP_INSTALLATION_PLAN.md](./NEXUS_DESKTOP_APP_INSTALLATION_PLAN.md)
for the persistence model and future app strategy.

### Return to Stock Desktop

Recreate the service without the premium override:

```sh
cd desktop
docker compose -f docker-compose.yml up -d --force-recreate
```

Your persistent files remain under `/DATA/Nexus`.

## Troubleshooting

### Theme Did Not Change

Confirm that the running container uses `nexus-desktop-premium:6b`, then run the
force-reapply commands above. A container restart is required for deterministic
XFCE reload.

```sh
docker inspect nexus-desktop --format '{{.Config.Image}}'
```

### Old Panel Still Appears

Run the force-reapply command and restart the premium container. The hook resets
only Nexus-managed panel XML and launchers.

### Wallpaper Did Not Apply

Confirm the wallpaper exists inside the premium container:

```sh
docker exec nexus-desktop test -f /opt/nexus-desktop/assets/wallpapers/nexus-cloud-dark.svg
```

Then force reapply and restart the container.

### Icons Still Look Old

Confirm `Papirus-Dark` exists inside the premium image:

```sh
docker exec nexus-desktop test -d /usr/share/icons/Papirus-Dark
```

Then force reapply and restart the container.

## Known Limitations

- Streamed `--with-desktop` installer staging currently downloads only the
  stock Compose file. Premium 6B requires a repository checkout until installer
  integration is updated.
- XFCE does not provide native glass blur, fully rounded application windows,
  or dock-grade animations.
- There is no trusted public HTTPS certificate, reverse proxy, or Nexus
  single sign-on yet.
- The dashboard card can open the desktop, but deeper lifecycle integration is
  deferred.
- Applications installed manually inside the running container, including VS
  Code installed from a `.deb`, may not survive a full container recreation
  unless they are baked into an image or provisioned by a future app-install
  workflow.
- Milestone 7A provides a terminal helper for `.deb` applications. A future
  Thunar action remains deferred: `Right-click .deb -> Install with Nexus`.
- Streamed desktop installer staging does not download `desktop/scripts/` yet,
  so the Milestone 7A helper currently requires a repository checkout.
- The pinned LinuxServer Webtop image supports `amd64` and `arm64`; current
  Webtop releases do not provide an `armv7` image.

## Configuration

The stock and premium Compose paths use the same optional environment variables:

| Variable | Default | Purpose |
| --- | --- | --- |
| `TZ` | `Etc/UTC` | Desktop timezone |
| `PUID` | `1000` | Linux UID used for persisted files |
| `PGID` | `1000` | Linux GID used for persisted files |
| `TITLE` | `Nexus Desktop` | Browser page title |
