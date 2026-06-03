# Nexus Desktop App Installation Plan

## Milestone 7A

Nexus Desktop can run graphical development applications inside its
browser-accessible XFCE session. Milestone 7A adds a small helper for installing
downloaded Debian packages without introducing a full app store.

## Validated Manual Flow

VS Code was downloaded as a `.deb`, installed manually with `apt`, launched
inside the browser desktop, and used to create:

```text
/config/Workspace/test.js
```

The file appeared on the EC2 host at:

```text
/DATA/Nexus/Workspace/test.js
```

This works because the desktop maps:

```text
/config/Workspace -> /DATA/Nexus/Workspace
```

A PackageKit warning appeared during the manual `.deb` installation but did not
block the install. The Nexus helper uses `apt` directly so its output and
failure status are visible in one log.

## Helper Flow

Repository checkouts mount `desktop/scripts/` read-only inside the container:

```text
/config/nexus/scripts
```

Install one downloaded application with:

```sh
docker exec -it nexus-desktop bash /config/nexus/scripts/nexus-install-deb.sh '/config/Downloads/code_*.deb'
```

The quoted wildcard is resolved inside the container. The helper refuses zero
matches and multiple matches. Install output is appended to:

```text
/config/nexus/logs/app-install.log
```

The downloads helper installs only when exactly one `.deb` exists:

```sh
docker exec -it nexus-desktop bash /config/nexus/scripts/nexus-install-downloaded-debs.sh
```

## AppImage Install Flow

Some applications ship as AppImages instead of Debian packages. Nexus registers
basic AppImage launchers without unpacking or modifying the application:

```sh
docker exec -it nexus-desktop bash /config/nexus/scripts/nexus-install-appimage.sh '/config/Downloads/MyApp*.AppImage'
```

Electron-based AppImages can opt into the same container-safe flags used by
Code-family launchers:

```sh
docker exec -it nexus-desktop bash /config/nexus/scripts/nexus-install-appimage.sh --name "My Editor" --electron '/config/Downloads/MyEditor*.AppImage'
```

The helper copies the file into `/config/nexus/appimages` and creates a launcher
under `/config/.local/share/applications`, so it survives container recreation.
Icon extraction, embedded metadata parsing, and AppImage update management
remain future work.

## Diagnostics

Use the desktop doctor when a launcher, default app, restore, or AppImage
registration does not behave as expected:

```sh
docker exec -u abc nexus-desktop bash /config/nexus/scripts/nexus-desktop-doctor.sh
```

It prints helper availability, persisted `.deb` and apt packages, registered
AppImages, MIME defaults, launcher `Exec=` lines, missing executable warnings,
Thunar actions, compatibility config files, and recent install/restore logs.
Use [NEXUS_DESKTOP_EC2_VALIDATION.md](./NEXUS_DESKTOP_EC2_VALIDATION.md) for
the live browser pass/fail checklist.

## Persistence Model

User files persist independently from installed applications:

- `/config/Workspace`, `/config/Downloads`, and `/config/Shared` are backed by
  `/DATA/Nexus` host folders.
- Applications installed into the running container may not survive a full
  container recreation.
- Applications that must survive recreation should eventually be baked into a
  maintained image or provisioned by a reproducible Nexus workflow.

## Future Strategy

- Use the opt-in Developer Edition image for common baked workstation tools.
- Keep controlled user-installed `.deb` support.
- Keep basic AppImage registration support; add richer icon extraction and
  metadata handling later.
- Investigate Flatpak later.
- Create a curated Nexus app catalog later.
- Keep `Nexus -> Open in Nexus Editor` for opening selected files and folders
  from Thunar.
- Keep `Nexus -> Install with Nexus` for installing one selected `.deb` or
  AppImage from Thunar.

## Developer Edition Milestone 7B

The repository-checkout Developer Edition image bakes common tools and
VSCodium into `nexus-desktop-developer:7b`. VSCodium is the reproducible default
editor and can open the persistent workspace with:

```sh
codium /config/Workspace
```

Official VS Code remains available for users who choose Microsoft's licensed
distribution:

```sh
docker exec -it nexus-desktop bash /config/nexus/scripts/nexus-install-deb.sh '/config/Downloads/code_*.deb'
```

Cursor also remains user-installed only. Manually installed applications may
disappear after container recreation; baked applications survive rebuilds.
Extend `Dockerfile.premium` with apt-based packages when an application should
be part of the maintained workstation image.

## GUI Launcher Repair Milestone 8B

Electron applications such as VSCodium, VS Code, and Cursor can launch from a
terminal while their default XFCE menu launchers appear to do nothing. Portal
integration can also prevent a selected file or folder from returning to the
editor.

Nexus Desktop runs an idempotent startup hook that discovers packaged Electron
applications and copies their installed system desktop files into:

```text
/config/.local/share/applications
```

The user-level copies preserve names, icons, and path arguments while adding
`GTK_USE_PORTAL=0`, `--no-sandbox`, `--disable-gpu`, and
`--xdg-portal-required-version=999`. These flags use GTK chooser fallback
behavior inside Webtop. The same hook repairs common stale executable paths
for VSCodium, VS Code, and Cursor when a desktop entry points at a missing
binary but the real binary exists in a standard install location. After
installing a `.deb`, repair launchers immediately without restarting:

```sh
docker exec -u abc nexus-desktop bash /config/nexus/scripts/fix-electron-launchers.sh
```

Unusual Electron desktop-file names can be listed one per line in
`/config/nexus/electron-launchers.conf`. Additional Electron runtime flags can
be listed one per line in `/config/nexus/electron-flags.conf`. Ordinary
non-Electron applications keep their vendor desktop launchers unchanged.

## Default Associations

After persisted apps are restored and launchers are repaired, Nexus Desktop
sets missing default file associations without overwriting valid user choices.
Folders and `file://` URLs default to Thunar. Common text and code MIME types
default to the first available coding editor launcher in this order: VSCodium,
VS Code, then Cursor.

This makes everyday actions such as double-clicking a project file or using
`xdg-open /config/Workspace/test.js` behave more like a normal desktop while
still allowing users to choose different defaults later.
For scripted changes, `nexus-set-default-app.sh` maps friendly names or
`.desktop` files to MIME types through `xdg-mime`.

Nexus also adds a Thunar action under `Nexus -> Open in Nexus Editor`. It opens
selected files or folders with the first available coding editor, bypassing an
Electron app's internal file picker when that picker fails to return the
selected path. Users can override the preferred editor with
`/config/nexus/editor-command.conf`.

For downloaded installers, Nexus adds `Nexus -> Install with Nexus` in Thunar.
It accepts one selected `.deb`, `.AppImage`, or `.appimage` file and dispatches
to `nexus-install-selected-app.sh`, which then calls the existing install
helpers.

For unpacked binaries or custom scripts, `nexus-register-app.sh` creates a
normal user-level desktop launcher:

```sh
docker exec -u abc nexus-desktop bash /config/nexus/scripts/nexus-register-app.sh --name "My Tool" /config/Shared/my-tool
```

Use `--electron` for Electron-style binaries that need container-safe flags.

## Persistent `.deb` Restore

The Nexus `.deb` helper copies successfully installed packages into:

```text
/config/nexus/packages
```

A startup hook restores cached packages that are missing after container
recreation, then the launcher hook refreshes GUI compatibility. User files
remain independent under `/DATA/Nexus`, and restore logs are appended to:

```text
/config/nexus/logs/app-restore.log
```

Raw manual `apt` installs are not cached automatically. To disable restore for
an application, remove its cached `.deb` and uninstall it normally.

## Ubuntu Repository Apps

Users are not restricted to downloaded `.deb` files or a curated app catalog.
Install normal Ubuntu repository packages with:

```sh
docker exec -it nexus-desktop bash /config/nexus/scripts/nexus-install-apt.sh vlc gimp
```

The helper records package names in `/config/nexus/apt-packages.txt`. The same
startup restore hook reinstalls missing repository packages after container
recreation. Users can edit the persistent list directly when needed.

## Current Limitations

- Milestone 7C streamed desktop installs stage `desktop/scripts/`. Servers
  staged by an earlier installer run must rerun the desktop installation to
  receive the helper scripts.
- The helper is deliberately limited to one `.deb` at a time.
- The helper does not verify vendor signatures beyond the package-manager
  behavior. Download applications only from trusted sources.
