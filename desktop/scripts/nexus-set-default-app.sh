#!/usr/bin/env bash

set -Eeuo pipefail

readonly CONFIG_ROOT="${NEXUS_DESKTOP_CONFIG_ROOT:-/config}"
readonly USER_APPLICATIONS_DIR="${CONFIG_ROOT}/.local/share/applications"
readonly SYSTEM_APPLICATIONS_DIR="${NEXUS_DESKTOP_SYSTEM_APPLICATIONS_DIR:-/usr/share/applications}"

log() {
	printf '[Nexus Default App] %s\n' "$*"
}

fail() {
	printf '[Nexus Default App] ERROR: %s\n' "$*" >&2
	exit 1
}

usage() {
	cat <<'EOF'
Usage:
  nexus-set-default-app.sh APP.desktop MIME_TYPE [MIME_TYPE ...]
  nexus-set-default-app.sh APP_NAME MIME_TYPE [MIME_TYPE ...]

Examples:
  nexus-set-default-app.sh cursor.desktop text/plain application/json
  nexus-set-default-app.sh cursor text/plain text/markdown
  nexus-set-default-app.sh thunar inode/directory
EOF
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

desktop_file_exists() {
	local desktop_file="$1"

	[[ -f "${USER_APPLICATIONS_DIR}/${desktop_file}" ]] ||
		[[ -f "${SYSTEM_APPLICATIONS_DIR}/${desktop_file}" ]]
}

resolve_desktop_file() {
	local app="$1"
	local candidate
	local -a candidates=()

	if [[ "${app}" == *.desktop ]]; then
		candidates=("${app}")
	else
		candidates=(
			"${app}.desktop"
			"${app,,}.desktop"
			"${app^}.desktop"
			"${app}-url-handler.desktop"
		)
	fi

	case "${app,,}" in
		codium | vscodium)
			candidates+=(codium.desktop)
			;;
		code | vscode | "vs-code" | "vs code")
			candidates+=(code.desktop)
			;;
		cursor)
			candidates+=(cursor.desktop)
			;;
		files | file-manager | thunar)
			candidates+=(thunar.desktop)
			;;
	esac

	for candidate in "${candidates[@]}"; do
		desktop_file_exists "${candidate}" && {
			printf '%s\n' "${candidate}"
			return 0
		}
	done

	return 1
}

validate_mime_type() {
	local mime_type="$1"

	[[ "${mime_type}" =~ ^[A-Za-z0-9.+_-]+/[A-Za-z0-9.+_-]+$ ]] ||
		fail "Invalid MIME type: ${mime_type}"
}

main() {
	local app desktop_file mime_type owner

	if (($# < 2)); then
		usage >&2
		fail "Pass an application and at least one MIME type."
	fi
	command -v xdg-mime >/dev/null 2>&1 ||
		fail "xdg-mime is unavailable in this container."

	app="$1"
	shift
	desktop_file="$(resolve_desktop_file "${app}")" ||
		fail "Could not find a desktop launcher for: ${app}"

	mkdir -p "${USER_APPLICATIONS_DIR}"
	for mime_type in "$@"; do
		validate_mime_type "${mime_type}"
		log "Setting ${mime_type} -> ${desktop_file}"
		HOME="${CONFIG_ROOT}" XDG_DATA_HOME="${CONFIG_ROOT}/.local/share" \
			xdg-mime default "${desktop_file}" "${mime_type}"
	done

	if command -v update-desktop-database >/dev/null 2>&1; then
		update-desktop-database "${USER_APPLICATIONS_DIR}" || true
	fi

	owner="$(resolve_owner)"
	if ((EUID == 0)); then
		chown -R "${owner}" "${USER_APPLICATIONS_DIR}"
	fi
}

main "$@"
