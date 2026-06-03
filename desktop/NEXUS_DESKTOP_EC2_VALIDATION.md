# Nexus Desktop EC2 Validation Checklist

This checklist records the live browser validation that cannot be proven from
local shell fixtures alone. Run it on a fresh or updated EC2 test instance after
deploying Nexus Desktop Developer Edition.

## Rollout

From the EC2 host:

```sh
cd ~/NexusOS
git pull
cd desktop
docker compose -f docker-compose.yml -f docker-compose.premium.yml up -d --force-recreate
```

Open:

```text
https://SERVER_IP:6901
```

Accept the self-signed certificate warning for this prototype. Keep port `6901`
restricted to trusted tester IP addresses.

## Baseline Host Checks

```sh
docker ps --filter name=nexus-desktop
docker exec nexus-desktop test -d /config/Workspace
docker exec nexus-desktop test -d /config/Downloads
docker exec nexus-desktop test -d /config/Shared
docker exec -u abc nexus-desktop bash /config/nexus/scripts/nexus-desktop-doctor.sh
```

Pass evidence:

- `nexus-desktop` is running.
- `/config/Workspace`, `/config/Downloads`, and `/config/Shared` exist.
- Doctor output shows helper scripts as `ok`.
- Doctor output shows `Open in Nexus Editor installed`.
- Doctor output has no unexpected `missing executable` entries for installed
  apps.

From a repository checkout, capture the host-side evidence into a timestamped
log:

```sh
cd ~/NexusOS
bash desktop/scripts/validate-nexus-desktop-ec2.sh
```

This script does not replace the browser checks below. It records container
state, helper availability, launcher/default output, app logs, and recent
container logs so failures have a consistent evidence bundle.

## VSCodium File and Folder Flow

Inside the browser desktop:

1. Open VSCodium from the menu.
2. Use `File -> Open Folder`.
3. Select `/config/Workspace`.
4. Confirm the Explorer sidebar shows Workspace contents.
5. Create or edit `/config/Workspace/vscodium-validation.js`.

Host evidence:

```sh
test -f /DATA/Nexus/Workspace/vscodium-validation.js
docker exec -u abc nexus-desktop grep '^Exec=' /config/.local/share/applications/codium.desktop
```

Pass evidence:

- The selected folder loads into VSCodium.
- The created file appears on the host at `/DATA/Nexus/Workspace`.
- The generated launcher contains `GTK_USE_PORTAL=0`, `--no-sandbox`,
  `--disable-gpu`, and `--xdg-portal-required-version=999`.

## Thunar Open-In-Editor Fallback

Inside the browser desktop:

1. Open Thunar.
2. Right-click `/config/Workspace`.
3. Select `Nexus -> Open in Nexus Editor`.
4. Confirm the folder opens in VSCodium, VS Code, or Cursor.

Optional Cursor preference:

```sh
echo cursor > /DATA/Nexus/Home/nexus/editor-command.conf
docker compose -f docker-compose.yml -f docker-compose.premium.yml restart nexus-desktop
```

Pass evidence:

- The selected file or folder opens in the preferred editor.
- This works even if an Electron app's internal file picker misbehaves.

## Cursor Install and Launch Flow

Download a Cursor Debian package into `/config/Downloads` from inside the
desktop browser or by copying it to `/DATA/Nexus/Downloads` on the host.

Terminal helper path:

```sh
docker exec -it nexus-desktop bash /config/nexus/scripts/nexus-install-deb.sh '/config/Downloads/cursor_*.deb'
docker exec -u abc nexus-desktop bash /config/nexus/scripts/fix-electron-launchers.sh
docker exec -u abc nexus-desktop grep '^Exec=' /config/.local/share/applications/cursor.desktop
```

Desktop path:

1. Open Thunar.
2. Right-click one Cursor `.deb` file.
3. Select `Nexus -> Install with Nexus`.
4. Launch Cursor from the menu or desktop icon.

Pass evidence:

- Cursor launches visibly from the icon/menu.
- Cursor can open `/config/Workspace` using `File -> Open Folder` or
  `Nexus -> Open in Nexus Editor`.
- `cursor.desktop` uses a valid executable path and includes the Electron-safe
  flags.
- `/config/nexus/packages` contains the cached Cursor `.deb`.

## AppImage Flow

Copy a test AppImage to `/DATA/Nexus/Downloads` or download it inside the
desktop.

Terminal helper path:

```sh
docker exec -it nexus-desktop bash /config/nexus/scripts/nexus-install-appimage.sh '/config/Downloads/*.AppImage'
```

For Electron-based AppImages:

```sh
docker exec -it nexus-desktop bash /config/nexus/scripts/nexus-install-appimage.sh --electron '/config/Downloads/*.AppImage'
```

Desktop path:

1. Open Thunar.
2. Right-click one `.AppImage` file.
3. Select `Nexus -> Install with Nexus`.
4. Launch the registered application from the XFCE menu.

Pass evidence:

- The AppImage is copied into `/config/nexus/appimages`.
- A `.desktop` launcher appears under `/config/.local/share/applications`.
- The app launches from its menu entry.
- Electron AppImage launchers include the Electron-safe flags when `--electron`
  is used.

## Custom Executable Registration

Create a simple persistent executable:

```sh
cat >/DATA/Nexus/Shared/nexus-hello-tool <<'EOF'
#!/usr/bin/env bash
xfce4-terminal --hold --command "bash -lc 'echo Nexus custom app works; pwd'"
EOF
chmod +x /DATA/Nexus/Shared/nexus-hello-tool
```

Register it:

```sh
docker exec -u abc nexus-desktop bash /config/nexus/scripts/nexus-register-app.sh --name "Nexus Hello Tool" /config/Shared/nexus-hello-tool
docker exec -u abc nexus-desktop grep '^Exec=' /config/.local/share/applications/nexus-nexus-hello-tool.desktop
```

Inside the browser desktop:

1. Open the XFCE application menu.
2. Launch `Nexus Hello Tool`.
3. Confirm a terminal window opens and prints the validation message.

Pass evidence:

- The custom executable remains under `/DATA/Nexus/Shared`.
- A launcher exists under `/config/.local/share/applications`.
- The app launches from the menu.
- For Electron-style custom binaries, repeating the registration with
  `--electron` adds the Electron-safe flags.

## Default Applications

Check defaults:

```sh
docker exec -u abc nexus-desktop xdg-mime query default inode/directory
docker exec -u abc nexus-desktop xdg-mime query default text/plain
docker exec -u abc nexus-desktop xdg-mime query default application/json
```

Set Cursor as the default editor for common code files:

```sh
docker exec -u abc nexus-desktop bash /config/nexus/scripts/nexus-set-default-app.sh cursor text/plain text/markdown application/json
```

Pass evidence:

- Folders default to Thunar.
- Text and code files default to the selected editor.
- Double-clicking a text/code file in Thunar opens the configured editor.

## Persistence After Recreate

After installing at least one `.deb`, one apt package, or one AppImage:

```sh
cd ~/NexusOS/desktop
docker compose -f docker-compose.yml -f docker-compose.premium.yml up -d --force-recreate
docker exec -u abc nexus-desktop bash /config/nexus/scripts/nexus-desktop-doctor.sh
```

Pass evidence:

- Files under `/DATA/Nexus/Workspace` remain present.
- Cached `.deb` packages are listed under `/config/nexus/packages`.
- AppImages are listed under `/config/nexus/appimages`.
- Apt package restore entries are listed from `/config/nexus/apt-packages.txt`
  when used.
- Doctor output does not show unexpected missing launchers.

## Failure Evidence To Capture

If an app still fails:

```sh
docker exec -u abc nexus-desktop bash /config/nexus/scripts/nexus-desktop-doctor.sh | tee nexus-desktop-doctor.log
docker exec nexus-desktop tail -100 /config/nexus/logs/app-install.log
docker exec nexus-desktop tail -100 /config/nexus/logs/app-restore.log
docker logs nexus-desktop --tail 120
```

Record:

- The app name and install method.
- Whether it launches from terminal.
- The generated `.desktop` `Exec=` line.
- Whether the executable path exists inside the container.
- Whether the failure is launch, file picker, default-app association, or
  persistence after recreate.
