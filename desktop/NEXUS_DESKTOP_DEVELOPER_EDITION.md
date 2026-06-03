# Nexus Desktop Developer Edition

## Milestone 7B

Nexus Desktop Developer Edition is the opt-in repository-checkout workstation
image:

```text
nexus-desktop-developer:7b
```

It keeps the persistent `/DATA/Nexus` folder model and Milestone 6B theme while
baking common development tools into a reproducible image.

## Included Tools

- Git, curl, wget, CA certificates, GnuPG, and common desktop utilities.
- Python 3, pip, and virtual environments.
- Ubuntu Node.js 22 LTS with Corepack.
- Build tools, unzip, jq, nano, and htop.
- XDG desktop portal services with the GTK backend for portal-aware GUI apps.
- GVfs backends, thumbnailing, archive handling, and Thunar volume integration.
- VSCodium as the baked editor.
- Arc-Dark, Papirus-Dark, Inter fonts, and the Nexus XFCE profile.

The separate Ubuntu `npm` package is intentionally omitted to keep the image
lean. Corepack is available for package-manager activation.

VSCodium is the distributable default. Official VS Code remains installable
through the Milestone 7A `.deb` helper for users who choose Microsoft's
licensed distribution. Cursor remains user-installed only. Ollama and AI
runtime bundling are deferred.

## Build and Deploy

```sh
cd ~/NexusOS
git pull
cd desktop
docker compose -f docker-compose.yml -f docker-compose.premium.yml build --pull nexus-desktop
docker compose -f docker-compose.yml -f docker-compose.premium.yml up -d --force-recreate
```

Install through the streamed Nexus Cloud installer:

```sh
curl -fsSL https://raw.githubusercontent.com/12ali26/NexusOS/main/scripts/install-nexus.sh | sudo bash -s -- --with-desktop --desktop-edition developer
```

The streamed installer stages the required desktop runtime files and builds
the same image locally. This takes longer than stock startup and requires
network access to Ubuntu packages and the signed VSCodium repository.

Open the persistent workspace:

```sh
codium /config/Workspace
```

The container path maps to:

```text
/config/Workspace -> /DATA/Nexus/Workspace
```

## Verify

```sh
docker exec nexus-desktop git --version
docker exec nexus-desktop python3 --version
docker exec nexus-desktop node --version
docker exec nexus-desktop corepack --version
docker exec -u abc nexus-desktop codium --version
```

Use `-u abc` for VSCodium verification because Electron refuses root
execution.

## GUI Launcher Repair

Milestone 8B runs a startup hook that creates user-level launchers for detected
Electron applications, including VSCodium, VS Code, and Cursor. It preserves
application names, icons, and path arguments while adding container-safe
sandbox, GPU, and GTK file-dialog fallback flags to each `Exec=` action. It
also repairs common stale executable paths for Code-family launchers when the
real binary is available in a standard location such as `/usr/bin`,
`/opt/Cursor`, or `/opt/cursor`. The generated launchers live under:

```text
/config/.local/share/applications
```

Run the idempotent repair manually after adding a new `.deb` application:

```sh
docker exec -u abc nexus-desktop bash /config/nexus/scripts/fix-electron-launchers.sh
```

Verify VSCodium:

```sh
docker exec -u abc nexus-desktop grep '^Exec=' /config/.local/share/applications/codium.desktop
```

For an Electron package that is not discovered automatically, add its desktop
filename to `/config/nexus/electron-launchers.conf` and rerun the repair.
For an Electron package that needs extra runtime flags, add one flag per line
to `/config/nexus/electron-flags.conf` and rerun the repair.
Inspect the generated `Exec=` line when an icon still fails:

```sh
docker exec -u abc nexus-desktop grep '^Exec=' /config/.local/share/applications/cursor.desktop
```

Nexus also sets missing default file associations after launchers are repaired.
Folders open with Thunar, and common text/code files open with the first
available coding editor in this order: VSCodium, VS Code, then Cursor. Existing
user choices in `/config/.local/share/applications/mimeapps.list` are preserved.
Users can set explicit defaults with
`/config/nexus/scripts/nexus-set-default-app.sh`, for example:

```sh
docker exec -u abc nexus-desktop bash /config/nexus/scripts/nexus-set-default-app.sh cursor text/plain application/json
```

Thunar also gets a `Nexus -> Open in Nexus Editor` action for selected files
or folders, which calls `/config/nexus/scripts/nexus-open-in-editor.sh`
directly. Set `/config/nexus/editor-command.conf` to `cursor`, `code`,
`codium`, or an executable path to change the preferred editor.
Downloaded `.deb` and AppImage files can be installed from Thunar with
`Nexus -> Install with Nexus`, which dispatches to the same reproducible helper
scripts used from the terminal.

Applications installed through `nexus-install-deb.sh` are cached under
`/config/nexus/packages` and restored when missing after container recreation.
Restore output is appended to `/config/nexus/logs/app-restore.log`.

Install Ubuntu repository applications with:

```sh
docker exec -it nexus-desktop bash /config/nexus/scripts/nexus-install-apt.sh vlc gimp
```

Selected repository packages persist in `/config/nexus/apt-packages.txt` and
are restored when missing after recreation.

Install AppImage applications with:

```sh
docker exec -it nexus-desktop bash /config/nexus/scripts/nexus-install-appimage.sh '/config/Downloads/MyApp*.AppImage'
```

Use `--electron` for Electron-based AppImages so their launcher receives the
same container-safe flags as VSCodium, VS Code, and Cursor.

Register unpacked binaries or custom scripts with:

```sh
docker exec -u abc nexus-desktop bash /config/nexus/scripts/nexus-register-app.sh --name "My Tool" /config/Shared/my-tool
```

## Persistence Model

Files under `/DATA/Nexus` survive restarts and container recreation. Tools
baked into `Dockerfile.premium` survive rebuilds. Applications installed
manually inside a running container may disappear when the container is
recreated.

To add another maintained apt-based application later, extend
`Dockerfile.premium`, rebuild the Developer Edition image, and recreate the
desktop service.

## Known Limits

- Developer Edition remains opt-in with `--desktop-edition developer`.
- Developer Edition supports `amd64` and `arm64`. Use stock desktop on `armv7`.
- Official VS Code and Cursor are not baked into the image.
- Ollama, Docker-in-Docker, heavy shell frameworks, and default editor
  extensions are deferred.
- Direct access remains `https://SERVER_IP:6901` with prototype HTTPS
  limitations.

## Return to Stock

Persistent files under `/DATA/Nexus` remain intact when switching editions:

```sh
sudo bash scripts/install-desktop.sh --desktop-edition stock
cd desktop
docker compose -f docker-compose.yml up -d --force-recreate
```
