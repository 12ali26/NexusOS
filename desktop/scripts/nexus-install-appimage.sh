#!/usr/bin/env bash

set -Eeuo pipefail

readonly CONFIG_ROOT="${NEXUS_DESKTOP_CONFIG_ROOT:-/config}"
readonly APPIMAGE_DIR="${CONFIG_ROOT}/nexus/appimages"
readonly LOG_DIR="${CONFIG_ROOT}/nexus/logs"
readonly LOG_FILE="${LOG_DIR}/app-install.log"
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
ELECTRON=0
APPIMAGE_INPUT=""

log() {
	printf '[Nexus AppImage Installer] %s\n' "$*"
}

fail() {
	printf '[Nexus AppImage Installer] ERROR: %s\n' "$*" >&2
	exit 1
}

usage() {
	cat <<'EOF'
Usage:
  nexus-install-appimage.sh [--name "App Name"] [--electron] PATH_OR_PATTERN.AppImage

Examples:
  nexus-install-appimage.sh '/config/Downloads/MyApp*.AppImage'
  nexus-install-appimage.sh --name "My Editor" --electron '/config/Downloads/MyEditor*.AppImage'
EOF
}

prepare_log() {
	mkdir -p "${LOG_DIR}"
	touch "${LOG_FILE}"
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

resolve_appimage_path() {
	local pattern="$1"
	local -a matches=()

	shopt -s nullglob
	# Intentionally expand the quoted caller pattern inside the container.
	# shellcheck disable=SC2206
	matches=(${pattern})
	shopt -u nullglob

	if ((${#matches[@]} == 0)); then
		fail "No AppImage matches: ${pattern}"
	fi
	if ((${#matches[@]} > 1)); then
		printf '[Nexus AppImage Installer] Multiple AppImages match %s:\n' "${pattern}" >&2
		printf '  %s\n' "${matches[@]}" >&2
		fail "Pass one specific AppImage file."
	fi

	printf '%s\n' "${matches[0]}"
}

app_id_from_name() {
	local name="$1"
	local app_id

	app_id="$(printf '%s\n' "${name}" |
		tr '[:upper:]' '[:lower:]' |
		sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')"
	[[ -n "${app_id}" ]] || app_id="appimage"
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

write_desktop_file() {
	local app_id="$1"
	local name="$2"
	local appimage_path="$3"
	local desktop_file="${USER_APPLICATIONS_DIR}/${app_id}.desktop"
	local -a flags=()
	local exec_line

	mkdir -p "${USER_APPLICATIONS_DIR}"
	exec_line="env GTK_USE_PORTAL=0 ${appimage_path}"
	if ((ELECTRON == 1)); then
		mapfile -t flags < <(read_electron_flags)
		exec_line+=" ${flags[*]}"
	fi
	exec_line+=" %F"

	cat >"${desktop_file}" <<EOF
[Desktop Entry]
Type=Application
Name=${name}
Exec=${exec_line}
Icon=application-x-executable
Terminal=false
Categories=Utility;
StartupNotify=true
EOF
	chmod 0644 "${desktop_file}"
	printf '%s\n' "${desktop_file}"
}

parse_args() {
	while (($#)); do
		case "$1" in
			--name)
				shift
				[[ -n "${1:-}" ]] || fail "--name requires a value."
				APP_NAME="$1"
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
		fail "Pass exactly one AppImage file path or quoted pattern."
	}
	APPIMAGE_INPUT="$1"
}

main() {
	local input_path appimage_path app_name app_id install_path desktop_file owner

	parse_args "$@"
	input_path="${APPIMAGE_INPUT}"
	appimage_path="$(resolve_appimage_path "${input_path}")"
	[[ -f "${appimage_path}" ]] || fail "File does not exist: ${appimage_path}"
	[[ "${appimage_path,,}" == *.appimage ]] || fail "Expected an .AppImage file: ${appimage_path}"

	prepare_log
	exec > >(tee -a "${LOG_FILE}") 2>&1
	trap 'status=$?; log "Installation failed with exit status ${status}."; exit "${status}"' ERR

	app_name="${APP_NAME:-${appimage_path##*/}}"
	app_name="${app_name%.AppImage}"
	app_name="${app_name%.appimage}"
	app_id="$(app_id_from_name "${app_name}")"
	install_path="${APPIMAGE_DIR}/${app_id}.AppImage"

	log "Installing AppImage: ${appimage_path}"
	mkdir -p "${APPIMAGE_DIR}" "${USER_APPLICATIONS_DIR}"
	install -m 0755 "${appimage_path}" "${install_path}"
	desktop_file="$(write_desktop_file "${app_id}" "${app_name}" "${install_path}")"
	log "Registered launcher: ${desktop_file}"

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
		chown -R "${owner}" "${APPIMAGE_DIR}" "${USER_APPLICATIONS_DIR}" "${LOG_DIR}"
	fi
	log "AppImage installation completed successfully."
}

main "$@"
