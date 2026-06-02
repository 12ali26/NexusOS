#!/usr/bin/env bash

set -Eeuo pipefail

readonly CONFIG_ROOT="${NEXUS_DESKTOP_CONFIG_ROOT:-/config}"
readonly LOG_DIR="${CONFIG_ROOT}/nexus/logs"
readonly LOG_FILE="${LOG_DIR}/app-install.log"
readonly APT_PACKAGE_FILE="${CONFIG_ROOT}/nexus/apt-packages.txt"
readonly LAUNCHER_REPAIR_SCRIPT="${CONFIG_ROOT}/nexus/scripts/fix-electron-launchers.sh"

log() {
	printf '[Nexus App Installer] %s\n' "$*"
}

fail() {
	printf '[Nexus App Installer] ERROR: %s\n' "$*" >&2
	exit 1
}

usage() {
	printf 'Usage: %s PACKAGE [PACKAGE ...]\n' "${0##*/}"
}

prepare_files() {
	sudo mkdir -p "${LOG_DIR}" "$(dirname "${APT_PACKAGE_FILE}")"
	sudo touch "${LOG_FILE}" "${APT_PACKAGE_FILE}"
	sudo chown "$(id -u):$(id -g)" "${LOG_DIR}" "${LOG_FILE}" "${APT_PACKAGE_FILE}"
}

validate_packages() {
	local package_name

	for package_name in "$@"; do
		[[ "${package_name}" =~ ^[a-z0-9][a-z0-9+.-]*(:[a-z0-9][a-z0-9-]*)?$ ]] ||
			fail "Invalid apt package name: ${package_name}"
	done
}

remember_packages() {
	local package_name

	for package_name in "$@"; do
		grep -Fxq "${package_name}" "${APT_PACKAGE_FILE}" ||
			printf '%s\n' "${package_name}" >>"${APT_PACKAGE_FILE}"
	done
	sort -u -o "${APT_PACKAGE_FILE}" "${APT_PACKAGE_FILE}"
}

main() {
	(($# > 0)) || {
		usage >&2
		fail "Pass at least one Ubuntu package name."
	}

	validate_packages "$@"
	prepare_files
	exec > >(tee -a "${LOG_FILE}") 2>&1
	trap 'status=$?; log "Installation failed with exit status ${status}."; exit "${status}"' ERR

	log "Refreshing apt package metadata..."
	sudo apt update
	log "Installing apt packages: $*"
	sudo apt install "$@" -y
	remember_packages "$@"

	if command -v update-desktop-database >/dev/null 2>&1; then
		log "Refreshing desktop application database..."
		update-desktop-database
	fi
	if [[ -x "${LAUNCHER_REPAIR_SCRIPT}" ]]; then
		log "Refreshing container-safe application launchers..."
		bash "${LAUNCHER_REPAIR_SCRIPT}"
	fi
	log "Installation completed successfully."
}

main "$@"
