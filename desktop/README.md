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

The streamed dashboard installer also defaults to stock desktop:

```sh
curl -fsSL https://raw.githubusercontent.com/12ali26/NexusOS/main/scripts/install-nexus.sh | sudo bash -s -- --with-desktop
```

## Developer Edition Milestone 7B

Milestone 7B expands the opt-in premium repository-checkout image into
`nexus-desktop-developer:7b`. It preserves the Milestone 6B visual profile and
adds a lightweight developer workstation:

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
- Git, curl, wget, Python 3, virtual environments, build tools, unzip, jq, nano,
  htop, and related workstation utilities.
- XDG desktop portal services with the GTK backend for portal-aware GUI apps.
- GVfs backends, thumbnails, archive handling, and Thunar volume integration
  for everyday file-manager workflows.
- Ubuntu Node.js 22 LTS with Corepack.
- VSCodium as the baked editor, available from the Whisker Menu and terminal:

```sh
codium /config/Workspace
```

The separate Ubuntu `npm` package is intentionally not installed because it
pulls a large dependency tree. Corepack is included with Ubuntu Node.js.
Official VS Code and Cursor remain user-installed `.deb` options.

See [NEXUS_DESKTOP_DEVELOPER_EDITION.md](./NEXUS_DESKTOP_DEVELOPER_EDITION.md)
for the baked tool list and [NEXUS_DESKTOP_UI_PLAN.md](./NEXUS_DESKTOP_UI_PLAN.md)
for the visual design and XFCE constraints.

### Build and Apply Developer Edition

From a NexusOS repository checkout:

```sh
cd desktop
docker compose -f docker-compose.yml -f docker-compose.premium.yml build --pull nexus-desktop
docker compose -f docker-compose.yml -f docker-compose.premium.yml up -d --force-recreate
```

Or install Developer Edition with the standalone installer:

```sh
sudo bash scripts/install-desktop.sh --desktop-edition developer
```

The dashboard installer can stage and build Developer Edition on the server:

```sh
curl -fsSL https://raw.githubusercontent.com/12ali26/NexusOS/main/scripts/install-nexus.sh | sudo bash -s -- --with-desktop --desktop-edition developer
```

The Developer Edition image includes the theme hook, assets, and baked tools.
No runtime package installation is required for the included workstation.

Verify the baked toolchain:

```sh
docker exec nexus-desktop git --version
docker exec nexus-desktop python3 --version
docker exec nexus-desktop node --version
docker exec nexus-desktop corepack --version
docker exec -u abc nexus-desktop codium --version
```

Use `-u abc` for VSCodium CLI verification because Electron refuses to run as
root.

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

## Electron App Launchers

Milestone 8B repairs GUI launchers for Electron apps inside the container.
Nexus automatically recognizes packaged Electron applications and explicitly
supports:

- VSCodium
- VS Code
- Cursor

On desktop startup, Nexus copies installed system launchers into:

```text
/config/.local/share/applications
```

Each user-level launcher keeps its original name, icon, file arguments, and
folder arguments while adding container-safe flags to `Exec=` actions:

```text
GTK_USE_PORTAL=0
--no-sandbox
--xdg-portal-required-version=999
```

The GTK fallback avoids container portal issues when selecting files or
folders from an Electron application. The repair is idempotent, so restarts do
not duplicate flags. Ordinary non-Electron applications continue using their
vendor desktop files without Nexus-specific changes.

Electron documents `--xdg-portal-required-version` as the Linux file-dialog
portal threshold switch: <https://www.electronjs.org/docs/latest/api/command-line-switches#--xdg-portal-required-versionversion>.

After pulling Milestone 8B, recreate the selected desktop variant once so the
startup-hook mount is added:

```sh
cd ~/NexusOS
git pull
cd desktop
docker compose -f docker-compose.yml -f docker-compose.premium.yml up -d --force-recreate
```

Run the repair manually after installing a new `.deb` without restarting:

```sh
docker exec -u abc nexus-desktop bash /config/nexus/scripts/fix-electron-launchers.sh
```

Inspect generated launchers for installed applications:

```sh
docker exec -u abc nexus-desktop grep '^Exec=' /config/.local/share/applications/codium.desktop
docker exec -u abc nexus-desktop grep '^Exec=' /config/.local/share/applications/code.desktop
docker exec -u abc nexus-desktop grep '^Exec=' /config/.local/share/applications/cursor.desktop
```

For an unusual Electron package that Nexus cannot discover automatically, add
its desktop-file basename to:

```text
/config/nexus/electron-launchers.conf
```

Use one filename per line, such as `my-editor.desktop`, then run the repair
command again.

## Persist Installed `.deb` Apps

Applications installed through `nexus-install-deb.sh` are copied into:

```text
/config/nexus/packages
```

Because `/config` maps to `/DATA/Nexus/Home`, the downloaded package remains
available after container recreation. At startup, Nexus restores cached `.deb`
applications that are missing from the current container before repairing
their launchers. Review restore logs with:

```sh
docker exec nexus-desktop tail -100 /config/nexus/logs/app-restore.log
```

To stop restoring an application, remove its cached `.deb` from
`/config/nexus/packages` and uninstall it normally.

## Install Ubuntu Repository Apps

Users can install ordinary Ubuntu applications by package name. Nexus records
the selected packages under persistent `/config` and restores them after
container recreation:

```sh
docker exec -it nexus-desktop bash /config/nexus/scripts/nexus-install-apt.sh vlc gimp
```

The persistent package list is:

```text
/config/nexus/apt-packages.txt
```

This workflow does not limit users to a Nexus-curated catalog. Users still have
their normal Linux desktop and terminal; the helper adds reproducible restore
behavior for applications installed from Ubuntu repositories.

### Return to Stock Desktop

Run the stock installer, then recreate the service without the premium
override:

```sh
sudo bash scripts/install-desktop.sh --desktop-edition stock
cd desktop
docker compose -f docker-compose.yml up -d --force-recreate
```

Your persistent files remain under `/DATA/Nexus`.

## Troubleshooting

### Theme Did Not Change

Confirm that the running container uses `nexus-desktop-developer:7b`, then run
the force-reapply commands above. A container restart is required for
deterministic XFCE reload.

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

### App Opens From Terminal but Not From Icon

Electron apps may require sandbox and file-dialog compatibility flags inside
the Webtop container. Terminal commands can work while an unpatched XFCE menu
launcher appears to do nothing, or while a file/folder chooser does not return
the selected path to the editor. Repair the user-level launchers:

```sh
docker exec -u abc nexus-desktop bash /config/nexus/scripts/fix-electron-launchers.sh
```

Then reopen the XFCE menu and launch the application normally.

## Known Limitations

- Streamed Developer Edition installation builds locally on the server and
  takes longer than stock startup. It requires access to Ubuntu packages and
  the signed VSCodium repository.
- XFCE does not provide native glass blur, fully rounded application windows,
  or dock-grade animations.
- There is no trusted public HTTPS certificate, reverse proxy, or Nexus
  single sign-on yet.
- The dashboard card can open the desktop, but deeper lifecycle integration is
  deferred.
- Applications installed manually with raw `apt` commands may not survive a
  full container recreation. Applications installed through the Nexus `.deb`
  helper or apt-package helper are restored from persistent `/config`.
- Milestone 7A provides a terminal helper for `.deb` applications. A future
  Thunar action remains deferred: `Right-click .deb -> Install with Nexus`.
- Developer Edition supports `amd64` and `arm64`. Use stock desktop on `armv7`.
- Ollama, AI runtime bundling, Docker-in-Docker, and default editor extensions
  remain deferred.
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
