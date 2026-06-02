#!/usr/bin/env bash

set -Eeuo pipefail

readonly CONFIG_ROOT="${NEXUS_DESKTOP_CONFIG_ROOT:-/config}"
readonly ASSETS_ROOT="${NEXUS_DESKTOP_ASSETS_ROOT:-/opt/nexus-desktop/assets}"
readonly STATE_DIR="${CONFIG_ROOT}/.nexus-desktop"
readonly FLAG_FILE="${STATE_DIR}/theme-applied-v1"
readonly XFCE_CONFIG_DIR="${CONFIG_ROOT}/.config/xfce4"
readonly XFCE_CHANNEL_DIR="${XFCE_CONFIG_DIR}/xfconf/xfce-perchannel-xml"
readonly XFCE_PANEL_DIR="${XFCE_CONFIG_DIR}/panel"
readonly BACKGROUND_DIR="${CONFIG_ROOT}/.local/share/backgrounds"
readonly WALLPAPER_FILE="${BACKGROUND_DIR}/nexus-cloud-dark.svg"
readonly TEMPLATE_DIR="${ASSETS_ROOT}/xfce/xfconf/xfce-perchannel-xml"
readonly LAUNCHER_DIR="${ASSETS_ROOT}/xfce/panel"

log() {
	printf '[Nexus Desktop Theme] %s\n' "$*"
}

fail() {
	printf '[Nexus Desktop Theme] ERROR: %s\n' "$*" >&2
	exit 1
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

copy_launchers() {
	local launcher

	for launcher in launcher-2 launcher-3 launcher-4; do
		rm -rf "${XFCE_PANEL_DIR:?}/${launcher}"
		mkdir -p "${XFCE_PANEL_DIR}/${launcher}"
		cp -a "${LAUNCHER_DIR}/${launcher}/." "${XFCE_PANEL_DIR}/${launcher}/"
	done
}

apply_theme() {
	local owner timestamp backup_dir

	if [[ -f "${FLAG_FILE}" ]]; then
		log "Theme already applied. Delete ${FLAG_FILE} to force a reapply."
		return
	fi

	require_file "${ASSETS_ROOT}/wallpapers/nexus-cloud-dark.svg"
	require_file "${TEMPLATE_DIR}/xsettings.xml"
	require_file "${TEMPLATE_DIR}/xfwm4.xml"
	require_file "${TEMPLATE_DIR}/xfce4-panel.xml"
	require_file "${TEMPLATE_DIR}/xfce4-desktop.xml"
	require_file "${LAUNCHER_DIR}/launcher-2/chromium.desktop"
	require_file "${LAUNCHER_DIR}/launcher-3/thunar.desktop"
	require_file "${LAUNCHER_DIR}/launcher-4/xfce4-terminal.desktop"

	mkdir -p "${STATE_DIR}"

	if [[ -d "${XFCE_CONFIG_DIR}" ]] &&
		find "${XFCE_CONFIG_DIR}" -mindepth 1 -print -quit | grep -q .; then
		timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
		backup_dir="${STATE_DIR}/backups/${timestamp}"
		log "Backing up existing XFCE profile to ${backup_dir}/xfce4..."
		mkdir -p "${backup_dir}"
		cp -a "${XFCE_CONFIG_DIR}" "${backup_dir}/xfce4"
	fi

	log "Applying Nexus Cloud XFCE defaults..."
	mkdir -p "${XFCE_CHANNEL_DIR}" "${XFCE_PANEL_DIR}" "${BACKGROUND_DIR}"
	install -m 0644 "${ASSETS_ROOT}/wallpapers/nexus-cloud-dark.svg" "${WALLPAPER_FILE}"
	install -m 0644 "${TEMPLATE_DIR}/xsettings.xml" "${XFCE_CHANNEL_DIR}/xsettings.xml"
	install -m 0644 "${TEMPLATE_DIR}/xfwm4.xml" "${XFCE_CHANNEL_DIR}/xfwm4.xml"
	install -m 0644 "${TEMPLATE_DIR}/xfce4-panel.xml" "${XFCE_CHANNEL_DIR}/xfce4-panel.xml"
	sed "s|@NEXUS_WALLPAPER@|${WALLPAPER_FILE}|g" \
		"${TEMPLATE_DIR}/xfce4-desktop.xml" >"${XFCE_CHANNEL_DIR}/xfce4-desktop.xml"
	chmod 0644 "${XFCE_CHANNEL_DIR}/xfce4-desktop.xml"
	copy_launchers

	owner="$(resolve_owner)"
	chown -R "${owner}" \
		"${STATE_DIR}" \
		"${XFCE_CONFIG_DIR}" \
		"${BACKGROUND_DIR}"

	touch "${FLAG_FILE}"
	chmod 0644 "${FLAG_FILE}"
	chown "${owner}" "${FLAG_FILE}"
	log "Nexus Cloud desktop theme applied."
}

apply_theme
