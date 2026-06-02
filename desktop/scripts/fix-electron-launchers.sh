#!/usr/bin/env bash

set -Eeuo pipefail

readonly CONFIG_ROOT="${NEXUS_DESKTOP_CONFIG_ROOT:-/config}"
readonly SYSTEM_APPLICATIONS_DIR="${NEXUS_DESKTOP_SYSTEM_APPLICATIONS_DIR:-/usr/share/applications}"
readonly USER_APPLICATIONS_DIR="${CONFIG_ROOT}/.local/share/applications"
readonly LAUNCHER_FILES=(
	codium.desktop
	codium-url-handler.desktop
	code.desktop
	code-url-handler.desktop
	cursor.desktop
	cursor-url-handler.desktop
)

log() {
	printf '[Nexus Desktop Launchers] %s\n' "$*"
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

patch_launcher() {
	local source_file="$1"
	local destination_file="$2"
	local temporary_file

	temporary_file="$(mktemp)"
	sed -E \
		'/^Exec=/ {
			/(^|[[:space:]])--no-sandbox([[:space:]]|$)/! s|^Exec=([^[:space:]]+)|Exec=\1 --no-sandbox|
		}' \
		"${source_file}" >"${temporary_file}"
	install -m 0644 "${temporary_file}" "${destination_file}"
	rm -f "${temporary_file}"
}

main() {
	local launcher_file
	local owner
	local repaired=0

	mkdir -p "${USER_APPLICATIONS_DIR}"
	for launcher_file in "${LAUNCHER_FILES[@]}"; do
		if [[ ! -f "${SYSTEM_APPLICATIONS_DIR}/${launcher_file}" ]]; then
			continue
		fi

		log "Installing container-safe user launcher: ${launcher_file}"
		patch_launcher \
			"${SYSTEM_APPLICATIONS_DIR}/${launcher_file}" \
			"${USER_APPLICATIONS_DIR}/${launcher_file}"
		repaired=1
	done

	owner="$(resolve_owner)"
	if (( EUID == 0 )); then
		chown -R "${owner}" "${USER_APPLICATIONS_DIR}"
	fi

	if command -v update-desktop-database >/dev/null 2>&1; then
		update-desktop-database "${USER_APPLICATIONS_DIR}" || true
	fi

	if (( repaired == 1 )); then
		log "Electron application launchers are ready."
	else
		log "No supported Electron application launchers are installed yet."
	fi
}

main "$@"
