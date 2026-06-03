#!/usr/bin/env bash

set -Eeuo pipefail

readonly CONFIG_ROOT="${NEXUS_DESKTOP_CONFIG_ROOT:-/config}"
readonly SCRIPT_DIR="${CONFIG_ROOT}/nexus/scripts"
readonly DEB_INSTALLER="${SCRIPT_DIR}/nexus-install-deb.sh"
readonly APPIMAGE_INSTALLER="${SCRIPT_DIR}/nexus-install-appimage.sh"

fail() {
	printf '[Nexus Install Selected] ERROR: %s\n' "$*" >&2
	exit 1
}

usage() {
	printf 'Usage: %s PATH.deb|PATH.AppImage\n' "${0##*/}"
}

main() {
	local selected_path

	(($# == 1)) || {
		usage >&2
		fail "Select exactly one installer file."
	}

	selected_path="$1"
	[[ -f "${selected_path}" ]] || fail "File does not exist: ${selected_path}"

	case "${selected_path,,}" in
		*.deb)
			[[ -x "${DEB_INSTALLER}" ]] || fail "Missing helper: ${DEB_INSTALLER}"
			exec bash "${DEB_INSTALLER}" "${selected_path}"
			;;
		*.appimage)
			[[ -x "${APPIMAGE_INSTALLER}" ]] || fail "Missing helper: ${APPIMAGE_INSTALLER}"
			exec bash "${APPIMAGE_INSTALLER}" "${selected_path}"
			;;
		*)
			fail "Unsupported installer type. Expected .deb or .AppImage."
			;;
	esac
}

main "$@"
