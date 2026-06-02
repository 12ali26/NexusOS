# Nexus Desktop UI Plan

## Milestone 6A

Nexus Desktop keeps the stable LinuxServer Webtop Ubuntu XFCE container and
applies a small Nexus-branded XFCE profile on first startup. The customization
is lightweight, reproducible, and isolated under `desktop/`.

The profile uses assets already available in the pinned Webtop image:

- `Greybird-dark` GTK and XFWM theme
- `elementary-xfce-dark` icon theme
- Chromium, Thunar File Manager, and XFCE Terminal

No packages are installed at startup. Papirus icons, VS Code or VSCodium, and
dock emulation are intentionally deferred.

## First-Run Flow

The Compose service mounts `scripts/` read-only at `/custom-cont-init.d`.
LinuxServer runs the executable `apply-nexus-theme.sh` hook after built-in init
and before desktop services start.

The hook:

1. Exits without changes when `/config/.nexus-desktop/theme-applied-v1` exists.
2. Backs up an existing XFCE profile under
   `/config/.nexus-desktop/backups/YYYYMMDDTHHMMSSZ/xfce4/`.
3. Installs the Nexus wallpaper, XFCE settings, bottom panel, and launchers.
4. Restores ownership to the remapped LinuxServer `abc` account.
5. Creates the flag file only after all changes succeed.

This gives new profiles a Nexus default while preserving later user
customizations across normal container restarts.

## Visual Direction

- Dark navy gradient Nexus Cloud wallpaper with restrained orange accents.
- Dark XFCE controls and window frames.
- Full-width bottom taskbar with a compact 34-pixel layout.
- Pinned Browser, Files, and Terminal launchers.
- Running applications, notification tray, audio control, clock, and session
  actions remain available.

## Reapply or Disable

To force the theme to reapply, delete the flag and restart the container:

```sh
rm /DATA/Nexus/Home/.nexus-desktop/theme-applied-v1
cd desktop
docker compose restart nexus-desktop
```

Reapplication creates a timestamped backup first. To disable automatic
application for a future deployment, remove the `/custom-cont-init.d` and
`/opt/nexus-desktop/assets` mounts from the Compose service. Existing profile
files remain persistent under `/DATA/Nexus/Home`.

## Deferred Work

- Evaluate Papirus icons in a maintained derived image.
- Add optional development tools separately from the visual profile.
- Integrate the visual profile into the standalone installer after EC2 testing.
- Add richer accent styling only if it remains stable across Webtop updates.
