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
- Add AppImage support later.
- Investigate Flatpak later.
- Create a curated Nexus app catalog later.
- Add a Thunar action later: `Right-click .deb -> Install with Nexus`.

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

## Current Limitations

- Milestone 7A requires a full NexusOS repository checkout. Streamed desktop
  installer staging does not download `desktop/scripts/` yet.
- The helper is deliberately limited to one `.deb` at a time.
- The helper does not verify vendor signatures beyond the package-manager
  behavior. Download applications only from trusted sources.
