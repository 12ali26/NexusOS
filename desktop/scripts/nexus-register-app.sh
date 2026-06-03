#!/usr/bin/env bash

set -Eeuo pipefail

readonly CONFIG_ROOT="${NEXUS_DESKTOP_CONFIG_ROOT:-/config}"
readonly USER_APPLICATIONS_DIR="${CONFIG_ROOT}/.local/share/applications"
readonly FLAGS_CONFIG="${CONFIG_ROOT}/nexus/electron-flags.conf"
readonly LAUNCHER_REPAIR_SCRIPT="${CONFIG_ROOT}/nexus/scripts/fix-electron-launchers.sh"
readonly DEFAULTS_SCRIPT="${CONFIG_ROOT}/nexus/scripts/configure-desktop-defaults.sh"
readonly -a DEFAULT_ELECTRON_FLAGS=(
	--xdg-portal-required-version=999
	--no-sandbox
	--disable-gpu
)

APP_NAME=""
APP_ID=""
CATEGORIES="Utility;"
ICON="application-x-executable"
TERMINAL="false"
ELECTRON=0
EXECUTABLE_PATH=""

log() {
	printf '[Nexus App Register] %s\n' "$*"
}

fail() {
	printf '[Nexus App Register] ERROR: %s\n' "$*" >&2
	exit 1
}

usage() {
	cat <<'EOF'
Usage:
  nexus-register-app.sh [options] /path/to/executable

Options:
  --name NAME        Display name for the launcher.
  --id ID            Launcher id. Defaults to a sanitized name.
  --icon ICON        Icon name or path. Defaults to application-x-executable.
  --category VALUE   Desktop category string. Defaults to Utility;.
  --terminal         Run in a terminal.
  --electron         Add Nexus Electron container flags.

Examples:
  nexus-register-app.sh --name "My Tool" /config/Shared/my-tool
  nexus-register-app.sh --name "My Electron App" --electron /config/Shared/my-electron-app
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

app_id_from_name() {
	local name="$1"
	local app_id

	app_id="$(printf '%s\n' "${name}" |
		tr '[:upper:]' '[:lower:]' |
		sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')"
	[[ -n "${app_id}" ]] || app_id="registered-app"
	printf 'nexus-%s\n' "${app_id}"
}

read_electron_flags() {
	local flag
	local -A seen_flags=()

	for flag in "${DEFAULT_ELECTRON_FLAGS[@]}"; do
		[[ -z "${seen_flags[${flag}]:-}" ]] || continue
		seen_flags["${flag}"]=1
		printf '%s\n' "${flag}"
	done

	[[ -f "${FLAGS_CONFIG}" ]] || return 0
	while IFS= read -r flag; do
		[[ -z "${seen_flags[${flag}]:-}" ]] || continue
		seen_flags["${flag}"]=1
		printf '%s\n' "${flag}"
	done < <(grep -Ev '^[[:space:]]*(#|$)' "${FLAGS_CONFIG}" || true)
}

parse_args() {
	while (($#)); do
		case "$1" in
			--name)
				shift
				[[ -n "${1:-}" ]] || fail "--name requires a value."
				APP_NAME="$1"
				;;
			--id)
				shift
				[[ -n "${1:-}" ]] || fail "--id requires a value."
				APP_ID="$1"
				;;
			--icon)
				shift
				[[ -n "${1:-}" ]] || fail "--icon requires a value."
				ICON="$1"
				;;
			--category | --categories)
				shift
				[[ -n "${1:-}" ]] || fail "--category requires a value."
				CATEGORIES="$1"
				;;
			--terminal)
				TERMINAL="true"
				;;
			--electron)
				ELECTRON=1
				;;
			-h | --help)
				usage
				exit 0
				;;
			--)
				shift
				break
				;;
			-*)
				usage >&2
				fail "Unknown argument: $1"
				;;
			*)
				break
				;;
		esac
		shift
	done

	(($# == 1)) || {
		usage >&2
		fail "Pass exactly one executable path."
	}
	EXECUTABLE_PATH="$1"
}

main() {
	local app_name app_id desktop_file exec_line owner
	local -a flags=()

	parse_args "$@"
	[[ -f "${EXECUTABLE_PATH}" ]] || fail "Executable does not exist: ${EXECUTABLE_PATH}"
	[[ -x "${EXECUTABLE_PATH}" ]] || fail "File is not executable: ${EXECUTABLE_PATH}"

	app_name="${APP_NAME:-${EXECUTABLE_PATH##*/}}"
	app_id="${APP_ID:-$(app_id_from_name "${app_name}")}"
	[[ "${app_id}" == *.desktop ]] && app_id="${app_id%.desktop}"
	desktop_file="${USER_APPLICATIONS_DIR}/${app_id}.desktop"

	mkdir -p "${USER_APPLICATIONS_DIR}"
	exec_line="env GTK_USE_PORTAL=0 ${EXECUTABLE_PATH}"
	if ((ELECTRON == 1)); then
		mapfile -t flags < <(read_electron_flags)
		exec_line+=" ${flags[*]}"
	fi
	exec_line+=" %F"

	cat >"${desktop_file}" <<EOF
[Desktop Entry]
Type=Application
Name=${app_name}
Exec=${exec_line}
Icon=${ICON}
Terminal=${TERMINAL}
Categories=${CATEGORIES}
StartupNotify=true
EOF
	chmod 0644 "${desktop_file}"

	if command -v update-desktop-database >/dev/null 2>&1; then
		update-desktop-database "${USER_APPLICATIONS_DIR}" || true
	fi
	if [[ -x "${LAUNCHER_REPAIR_SCRIPT}" ]]; then
		bash "${LAUNCHER_REPAIR_SCRIPT}"
	fi
	if [[ -x "${DEFAULTS_SCRIPT}" ]]; then
		bash "${DEFAULTS_SCRIPT}"
	fi

	owner="$(resolve_owner)"
	if ((EUID == 0)); then
		chown -R "${owner}" "${USER_APPLICATIONS_DIR}"
	fi
	log "Registered ${app_name}: ${desktop_file}"
}

main "$@"
