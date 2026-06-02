#!/usr/bin/env bash

set -Eeuo pipefail

readonly CONFIG_ROOT="${NEXUS_DESKTOP_CONFIG_ROOT:-/config}"
readonly DOWNLOADS_DIR="${CONFIG_ROOT}/Downloads"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly INSTALLER="${SCRIPT_DIR}/nexus-install-deb.sh"

log() {
	printf '[Nexus Downloads Installer] %s\n' "$*"
}

fail() {
	printf '[Nexus Downloads Installer] ERROR: %s\n' "$*" >&2
	exit 1
}

main() {
	local -a deb_files=()

	shopt -s nullglob
	deb_files=("${DOWNLOADS_DIR}"/*.deb)
	shopt -u nullglob

	if ((${#deb_files[@]} == 0)); then
		fail "No .deb files found in ${DOWNLOADS_DIR}."
	fi

	log "Downloaded .deb files:"
	printf '  %s\n' "${deb_files[@]}"

	if ((${#deb_files[@]} > 1)); then
		fail "Multiple .deb files found. Run nexus-install-deb.sh with one specific file."
	fi

	log "Installing the only downloaded .deb file..."
	exec bash "${INSTALLER}" "${deb_files[0]}"
}

main "$@"
