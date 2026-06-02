#!/usr/bin/env bash

set -Eeuo pipefail

readonly CONFIG_ROOT="${NEXUS_DESKTOP_CONFIG_ROOT:-/config}"
readonly LOG_DIR="${CONFIG_ROOT}/nexus/logs"
readonly LOG_FILE="${LOG_DIR}/app-install.log"
readonly PACKAGE_DIR="${CONFIG_ROOT}/nexus/packages"
readonly LAUNCHER_REPAIR_SCRIPT="${CONFIG_ROOT}/nexus/scripts/fix-electron-launchers.sh"

log() {
	printf '[Nexus App Installer] %s\n' "$*"
}

fail() {
	printf '[Nexus App Installer] ERROR: %s\n' "$*" >&2
	exit 1
}

usage() {
	printf 'Usage: %s PATH_OR_PATTERN.deb\n' "${0##*/}"
}

prepare_log() {
	sudo mkdir -p "${LOG_DIR}"
	sudo touch "${LOG_FILE}"
	sudo chown "$(id -u):$(id -g)" "${LOG_DIR}" "${LOG_FILE}"
}

resolve_deb_path() {
	local pattern="$1"
	local -a matches=()

	shopt -s nullglob
	# Intentionally expand the quoted caller pattern inside the container.
	# shellcheck disable=SC2206
	matches=(${pattern})
	shopt -u nullglob

	if ((${#matches[@]} == 0)); then
		fail "No .deb file matches: ${pattern}"
	fi
	if ((${#matches[@]} > 1)); then
		printf '[Nexus App Installer] Multiple .deb files match %s:\n' "${pattern}" >&2
		printf '  %s\n' "${matches[@]}" >&2
		fail "Pass one specific .deb file."
	fi

	printf '%s\n' "${matches[0]}"
}

install_deb() {
	local deb_path="$1"
	local package_name

	[[ -f "${deb_path}" ]] || fail "File does not exist: ${deb_path}"
	[[ "${deb_path,,}" == *.deb ]] || fail "Expected a .deb file: ${deb_path}"

	prepare_log
	exec > >(tee -a "${LOG_FILE}") 2>&1
	trap 'status=$?; log "Installation failed with exit status ${status}."; exit "${status}"' ERR

	log "Selected package: ${deb_path}"
	log "Refreshing apt package metadata..."
	sudo apt update
	log "Installing package..."
	sudo apt install "${deb_path}" -y

	log "Saving package for restore after container recreation..."
	package_name="$(dpkg-deb --field "${deb_path}" Package 2>/dev/null || true)"
	[[ -n "${package_name}" ]] || fail "Installed package metadata is missing its package name: ${deb_path}"
	sudo mkdir -p "${PACKAGE_DIR}"
	sudo install -m 0644 "${deb_path}" "${PACKAGE_DIR}/${package_name}.deb"
	sudo chown -R "$(id -u):$(id -g)" "${PACKAGE_DIR}"

	if command -v update-desktop-database >/dev/null 2>&1; then
		log "Refreshing desktop application database..."
		update-desktop-database
	else
		log "Desktop database refresh tool is unavailable; skipping."
	fi

	if [[ -x "${LAUNCHER_REPAIR_SCRIPT}" ]]; then
		log "Refreshing container-safe application launchers..."
		bash "${LAUNCHER_REPAIR_SCRIPT}"
	else
		log "Launcher repair helper is unavailable; restart Nexus Desktop after installing an Electron application."
	fi

	log "Installation completed successfully."
}

main() {
	local deb_path

	(($# == 1)) || {
		usage >&2
		fail "Pass exactly one .deb file path or quoted pattern."
	}

	deb_path="$(resolve_deb_path "$1")"
	install_deb "${deb_path}"
}

main "$@"
