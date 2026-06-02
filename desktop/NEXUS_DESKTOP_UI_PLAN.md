# Nexus Desktop UI Plan

## Milestone 6B

Nexus Desktop already works as a persistent browser-accessible XFCE workspace,
but the stock session still looks like a remote lab machine. Milestone 6B adds
an opt-in premium image while preserving the stable stock Compose path used by
streamed installs.

## Current Problems

- Stock XFCE panels, window borders, icons, and menus feel dated.
- The file manager and terminal do not emphasize the persistent Nexus folders.
- The first-run profile lacks a polished menu, consistent icons, and a branded
  browser start page.
- Existing `/DATA/Nexus/Home` profiles retain earlier XFCE settings unless a
  versioned upgrade applies a new profile once.

## Target Identity

- Calm navy and charcoal surfaces with restrained Nexus orange highlights.
- A single dark bottom taskbar with a modern Whisker application menu.
- Consistent `Papirus-Dark` icons, `Arc-Dark` GTK and XFWM styling, Breeze
  cursors, and Inter UI fonts.
- Intentional access to Browser, Files, Terminal, Workspace, and Settings.
- A focused desktop with only Workspace, Downloads, and Shared shortcuts.

## Premium Architecture

`Dockerfile.premium` builds from the pinned LinuxServer Webtop image and
installs Ubuntu-packaged visual dependencies:

```text
arc-theme
fonts-inter
papirus-icon-theme
xfce4-whiskermenu-plugin
```

The image bakes the assets into `/opt/nexus-desktop/assets` and the executable
theme hook into `/custom-cont-init.d/apply-nexus-theme.sh`. No packages are
installed at runtime, and no external theme repositories are cloned.

The base `docker-compose.yml` intentionally remains stock for streamed
installer compatibility. Repository checkouts opt into premium styling with
`docker-compose.premium.yml`.

## First-Run and Force Flow

The premium hook creates:

```text
/config/.nexus-desktop/theme-applied-v2
```

Because the flag is versioned, existing Milestone 6A profiles receive the 6B
upgrade once after the premium container is recreated. Before application, the
hook backs up the current XFCE profile to:

```text
/config/.config/xfce4.backup-YYYYMMDDTHHMMSSZ
```

Existing GTK bookmarks are backed up separately. The hook only resets
Nexus-managed visual settings on `--force`; it never deletes user files or the
Workspace, Downloads, Shared, and Desktop directories.

Run a deterministic manual reapply with:

```sh
docker exec nexus-desktop bash /custom-cont-init.d/apply-nexus-theme.sh --force
cd ~/NexusOS/desktop
docker compose -f docker-compose.yml -f docker-compose.premium.yml restart nexus-desktop
```

## XFCE Constraints

XFCE can provide a clean, lightweight desktop, but it does not guarantee native
glass blur, fully rounded application windows, or dock-grade animations.
Milestone 6B uses stable opacity and dark styling rather than fragile desktop
effects. A later custom desktop base can evaluate stronger compositor effects,
more application defaults, and optional developer tooling.

## Deferred Work

- Publish or stage premium assets through the streamed installer.
- Add VS Code or VSCodium only as an explicit developer-workstation feature.
- Evaluate a maintained custom base image if deeper rounded-window styling,
  blur, or curated application bundles become product requirements.
