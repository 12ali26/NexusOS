#!/usr/bin/env bash

set -Eeuo pipefail

readonly CONFIG_ROOT="${NEXUS_DESKTOP_CONFIG_ROOT:-/config}"
readonly ASSETS_ROOT="${NEXUS_DESKTOP_ASSETS_ROOT:-/opt/nexus-desktop/assets}"
readonly STATE_DIR="${CONFIG_ROOT}/.nexus-desktop"
readonly FLAG_FILE="${STATE_DIR}/theme-applied-v2"
readonly XFCE_CONFIG_DIR="${CONFIG_ROOT}/.config/xfce4"
readonly XFCE_CHANNEL_DIR="${XFCE_CONFIG_DIR}/xfconf/xfce-perchannel-xml"
readonly XFCE_PANEL_DIR="${XFCE_CONFIG_DIR}/panel"
readonly TERMINAL_DIR="${XFCE_CONFIG_DIR}/terminal"
readonly GTK_CONFIG_DIR="${CONFIG_ROOT}/.config/gtk-3.0"
readonly GTK_BOOKMARKS="${GTK_CONFIG_DIR}/bookmarks"
readonly BACKGROUND_DIR="${CONFIG_ROOT}/.local/share/backgrounds"
readonly WALLPAPER_FILE="${BACKGROUND_DIR}/nexus-cloud-dark.svg"
readonly DESKTOP_DIR="${CONFIG_ROOT}/Desktop"
readonly TEMPLATE_DIR="${ASSETS_ROOT}/xfce"
readonly PANEL_ASSET_DIR="${TEMPLATE_DIR}/panel"
readonly CHANNEL_ASSET_DIR="${TEMPLATE_DIR}/xfconf/xfce-perchannel-xml"
readonly DESKTOP_ASSET_DIR="${ASSETS_ROOT}/desktop"
readonly TERMINAL_ASSET="${TEMPLATE_DIR}/terminal/terminalrc"
readonly WHISKER_ASSET="${PANEL_ASSET_DIR}/whiskermenu-1.rc"
readonly WHISKER_CONFIG="${XFCE_PANEL_DIR}/whiskermenu-1.rc"
readonly MANAGED_CHANNELS=(xsettings.xml xfwm4.xml xfce4-panel.xml xfce4-desktop.xml thunar.xml)
readonly MANAGED_LAUNCHERS=(launcher-2 launcher-3 launcher-4 launcher-5 launcher-6)
readonly MANAGED_SHORTCUTS=(Workspace.desktop Downloads.desktop Shared.desktop)

FORCE=0

log() {
	printf '[Nexus Desktop Theme] %s\n' "$*"
}

fail() {
	printf '[Nexus Desktop Theme] ERROR: %s\n' "$*" >&2
	exit 1
}

usage() {
	printf 'Usage: %s [--force]\n' "${0##*/}"
}

parse_args() {
	while (($#)); do
		case "$1" in
			--force)
				FORCE=1
				;;
			-h | --help)
				usage
				exit 0
				;;
			*)
				usage >&2
				fail "Unknown argument: $1"
				;;
		esac
		shift
	done
}

require_file() {
	[[ -f "$1" ]] || fail "Missing required asset: $1"
}

resolve_owner() {
	if [[ -n "${NEXUS_DESKTOP_OWNER:-}" ]]; then
		printf '%s\n' "${NEXUS_DESKTOP_OWNER}"
	elif id abc >/dev/null 2>&1; then
		printf 'abc:abc\n'
	else
		printf '%s:%s\n' "$(id -u)" "$(id -g)"
	fi
}

validate_assets() {
	local channel launcher shortcut
	local -A launcher_files=(
		[launcher-2]="chromium.desktop"
		[launcher-3]="thunar.desktop"
		[launcher-4]="xfce4-terminal.desktop"
		[launcher-5]="workspace.desktop"
		[launcher-6]="settings.desktop"
	)

	require_file "${ASSETS_ROOT}/wallpapers/nexus-cloud-dark.svg"
	require_file "${TERMINAL_ASSET}"
	require_file "${WHISKER_ASSET}"
	for channel in "${MANAGED_CHANNELS[@]}"; do
		require_file "${CHANNEL_ASSET_DIR}/${channel}"
	done
	for launcher in "${MANAGED_LAUNCHERS[@]}"; do
		require_file "${PANEL_ASSET_DIR}/${launcher}/${launcher_files[${launcher}]}"
	done
	for shortcut in "${MANAGED_SHORTCUTS[@]}"; do
		require_file "${DESKTOP_ASSET_DIR}/${shortcut}"
	done
	require_file "${ASSETS_ROOT}/welcome/index.html"
}

backup_visual_config() {
	local timestamp="$1"

	if [[ -d "${XFCE_CONFIG_DIR}" ]] &&
		find "${XFCE_CONFIG_DIR}" -mindepth 1 -print -quit | grep -q .; then
		log "Backing up XFCE profile to ${XFCE_CONFIG_DIR}.backup-${timestamp}..."
		cp -a "${XFCE_CONFIG_DIR}" "${XFCE_CONFIG_DIR}.backup-${timestamp}"
	fi

	if [[ -f "${GTK_BOOKMARKS}" ]]; then
		log "Backing up GTK bookmarks to ${GTK_BOOKMARKS}.backup-${timestamp}..."
		cp -a "${GTK_BOOKMARKS}" "${GTK_BOOKMARKS}.backup-${timestamp}"
	fi
}

reset_managed_visual_config() {
	local channel launcher shortcut

	log "Resetting Nexus-managed visual settings for forced reapply..."
	for channel in "${MANAGED_CHANNELS[@]}"; do
		rm -f "${XFCE_CHANNEL_DIR}/${channel}"
	done
	for launcher in "${MANAGED_LAUNCHERS[@]}"; do
		rm -rf "${XFCE_PANEL_DIR:?}/${launcher}"
	done
	rm -f "${TERMINAL_DIR}/terminalrc"
	rm -f "${WHISKER_CONFIG}"
	for shortcut in "${MANAGED_SHORTCUTS[@]}"; do
		rm -f "${DESKTOP_DIR}/${shortcut}"
	done
}

install_wallpaper() {
	log "Installing Nexus Cloud wallpaper..."
	mkdir -p "${BACKGROUND_DIR}"
	install -m 0644 "${ASSETS_ROOT}/wallpapers/nexus-cloud-dark.svg" "${WALLPAPER_FILE}"
}

install_xfce_channels() {
	local channel

	log "Configuring GTK, XFWM, panel, and Thunar defaults..."
	mkdir -p "${XFCE_CHANNEL_DIR}"
	for channel in "${MANAGED_CHANNELS[@]}"; do
		if [[ "${channel}" == "xfce4-desktop.xml" ]]; then
			sed "s|@NEXUS_WALLPAPER@|${WALLPAPER_FILE}|g" \
				"${CHANNEL_ASSET_DIR}/${channel}" >"${XFCE_CHANNEL_DIR}/${channel}"
			chmod 0644 "${XFCE_CHANNEL_DIR}/${channel}"
		else
			install -m 0644 "${CHANNEL_ASSET_DIR}/${channel}" "${XFCE_CHANNEL_DIR}/${channel}"
		fi
	done
}

install_panel_launchers() {
	local launcher

	log "Installing Nexus panel launchers..."
	mkdir -p "${XFCE_PANEL_DIR}"
	for launcher in "${MANAGED_LAUNCHERS[@]}"; do
		rm -rf "${XFCE_PANEL_DIR:?}/${launcher}"
		mkdir -p "${XFCE_PANEL_DIR}/${launcher}"
		cp -a "${PANEL_ASSET_DIR}/${launcher}/." "${XFCE_PANEL_DIR}/${launcher}/"
	done
	install -m 0644 "${WHISKER_ASSET}" "${WHISKER_CONFIG}"
}

install_terminal_profile() {
	log "Installing dark terminal profile..."
	mkdir -p "${TERMINAL_DIR}"
	install -m 0644 "${TERMINAL_ASSET}" "${TERMINAL_DIR}/terminalrc"
}

merge_bookmarks() {
	local bookmark
	local -a bookmarks=(
		"file://${CONFIG_ROOT} Home"
		"file://${CONFIG_ROOT}/Workspace Workspace"
		"file://${CONFIG_ROOT}/Downloads Downloads"
		"file://${CONFIG_ROOT}/Shared Shared"
	)

	log "Adding Nexus folders to file-manager bookmarks..."
	mkdir -p "${GTK_CONFIG_DIR}"
	touch "${GTK_BOOKMARKS}"
	for bookmark in "${bookmarks[@]}"; do
		grep -Fxq "${bookmark}" "${GTK_BOOKMARKS}" || printf '%s\n' "${bookmark}" >>"${GTK_BOOKMARKS}"
	done
}

install_desktop_shortcuts() {
	local shortcut

	log "Installing Nexus folder shortcuts..."
	mkdir -p "${DESKTOP_DIR}"
	for shortcut in "${MANAGED_SHORTCUTS[@]}"; do
		install -m 0755 "${DESKTOP_ASSET_DIR}/${shortcut}" "${DESKTOP_DIR}/${shortcut}"
	done
}

restore_ownership() {
	local owner="$1"

	log "Restoring desktop-profile ownership to ${owner}..."
	chown -R "${owner}" \
		"${STATE_DIR}" \
		"${XFCE_CONFIG_DIR}" \
		"${BACKGROUND_DIR}" \
		"${DESKTOP_DIR}"
	chown "${owner}" "${GTK_BOOKMARKS}"
}

apply_theme() {
	local owner timestamp

	if [[ -f "${FLAG_FILE}" && "${FORCE}" -eq 0 ]]; then
		log "Premium theme already applied. Run with --force to reapply."
		return
	fi

	validate_assets
	mkdir -p "${STATE_DIR}"
	timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
	backup_visual_config "${timestamp}"

	if ((FORCE == 1)); then
		reset_managed_visual_config
	fi

	install_wallpaper
	install_xfce_channels
	install_panel_launchers
	install_terminal_profile
	merge_bookmarks
	install_desktop_shortcuts

	owner="$(resolve_owner)"
	touch "${FLAG_FILE}"
	chmod 0644 "${FLAG_FILE}"
	restore_ownership "${owner}"
	log "Premium Nexus Cloud desktop theme applied. Restart the container to reload XFCE."
}

parse_args "$@"
apply_theme
