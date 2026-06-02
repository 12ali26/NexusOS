#!/usr/bin/env bash

set -Eeuo pipefail

readonly CONFIG_ROOT="${NEXUS_DESKTOP_CONFIG_ROOT:-/config}"
readonly SYSTEM_APPLICATIONS_DIR="${NEXUS_DESKTOP_SYSTEM_APPLICATIONS_DIR:-/usr/share/applications}"
readonly USER_APPLICATIONS_DIR="${CONFIG_ROOT}/.local/share/applications"
readonly DESKTOP_DIR="${CONFIG_ROOT}/Desktop"
readonly ELECTRON_LAUNCHER_CONFIG="${CONFIG_ROOT}/nexus/electron-launchers.conf"
readonly -a KNOWN_ELECTRON_LAUNCHERS=(
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

warn() {
	printf '[Nexus Desktop Launchers] WARNING: %s\n' "$*" >&2
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

is_known_launcher() {
	local launcher_file="$1"
	local known_launcher

	for known_launcher in "${KNOWN_ELECTRON_LAUNCHERS[@]}"; do
		[[ "${launcher_file}" == "${known_launcher}" ]] && return 0
	done
	return 1
}

is_configured_launcher() {
	local launcher_file="$1"

	[[ -f "${ELECTRON_LAUNCHER_CONFIG}" ]] || return 1
	grep -Ev '^[[:space:]]*(#|$)' "${ELECTRON_LAUNCHER_CONFIG}" |
		grep -Fxq "${launcher_file}"
}

extract_exec_command() {
	local launcher_path="$1"
	local exec_line

	exec_line="$(sed -nE 's/^Exec=([^[:space:]]+).*/\1/p' "${launcher_path}" | head -n 1)"
	[[ "${exec_line}" == "env" ]] &&
		exec_line="$(sed -nE 's/^Exec=env([[:space:]]+[[:alnum:]_]+=[^[:space:]]+)*[[:space:]]+([^[:space:]]+).*/\2/p' "${launcher_path}" | head -n 1)"
	printf '%s\n' "${exec_line}"
}

is_electron_launcher() {
	local launcher_path="$1"
	local launcher_file="${launcher_path##*/}"
	local exec_command
	local exec_dir

	is_known_launcher "${launcher_file}" && return 0
	is_configured_launcher "${launcher_file}" && return 0

	exec_command="$(extract_exec_command "${launcher_path}")"
	[[ -n "${exec_command}" ]] || return 1
	exec_command="${exec_command#\"}"
	exec_command="${exec_command%\"}"
	if [[ "${exec_command}" != /* ]]; then
		exec_command="$(command -v "${exec_command}" 2>/dev/null || true)"
	fi
	[[ -n "${exec_command}" ]] || return 1

	exec_dir="$(dirname "${exec_command}")"
	[[ -d "${exec_dir}/resources/app" ]] ||
		[[ -f "${exec_dir}/resources/app.asar" ]] ||
		[[ -f "${exec_dir}/resources/default_app.asar" ]] ||
		[[ "${exec_command##*/}" == "electron" ]]
}

patch_launcher() {
	local source_file="$1"
	local destination_file="$2"
	local temporary_file

	temporary_file="$(mktemp)"
	sed -E '
		/^Exec=/ {
			/^Exec=env([[:space:]]|$)/! s/^Exec=/Exec=env GTK_USE_PORTAL=0 /
			/^Exec=env([[:space:]]|$)/ {
				/(^|[[:space:]])GTK_USE_PORTAL=/! s/^Exec=env/Exec=env GTK_USE_PORTAL=0/
			}
			/(^|[[:space:]])--no-sandbox([[:space:]]|$)/! s|^(Exec=env([[:space:]]+[[:alnum:]_]+=[^[:space:]]+)*[[:space:]]+[^[:space:]]+)|\1 --no-sandbox|
			/(^|[[:space:]])--xdg-portal-required-version=/! s|^(Exec=env([[:space:]]+[[:alnum:]_]+=[^[:space:]]+)*[[:space:]]+[^[:space:]]+)|\1 --xdg-portal-required-version=999|
		}
	' "${source_file}" >"${temporary_file}"
	install -m 0644 "${temporary_file}" "${destination_file}"
	rm -f "${temporary_file}"
}

repair_desktop_shortcut() {
	local launcher_file="$1"
	local source_file="$2"
	local desktop_shortcut="${DESKTOP_DIR}/${launcher_file}"

	[[ -f "${desktop_shortcut}" ]] || return 0
	log "Refreshing desktop shortcut: ${launcher_file}"
	patch_launcher "${source_file}" "${desktop_shortcut}"
	chmod 0755 "${desktop_shortcut}"
}

repair_launchers() {
	local launcher_path
	local launcher_file
	local repaired=0

	mkdir -p "${USER_APPLICATIONS_DIR}"
	while IFS= read -r -d '' launcher_path; do
		is_electron_launcher "${launcher_path}" || continue
		launcher_file="${launcher_path##*/}"
		log "Installing container-safe user launcher: ${launcher_file}"
		patch_launcher "${launcher_path}" "${USER_APPLICATIONS_DIR}/${launcher_file}"
		repair_desktop_shortcut "${launcher_file}" "${launcher_path}"
		repaired=1
	done < <(find "${SYSTEM_APPLICATIONS_DIR}" -maxdepth 1 -type f -name '*.desktop' -print0 | sort -z)

	if (( repaired == 1 )); then
		log "Electron application launchers are ready."
	else
		log "No Electron application launchers are installed yet."
	fi
}

warn_about_stale_desktop_shortcuts() {
	local desktop_shortcut
	local launcher_file

	[[ -d "${DESKTOP_DIR}" ]] || return 0
	for desktop_shortcut in "${DESKTOP_DIR}"/*.desktop; do
		[[ -f "${desktop_shortcut}" ]] || continue
		launcher_file="${desktop_shortcut##*/}"
		if is_known_launcher "${launcher_file}" &&
			[[ ! -f "${SYSTEM_APPLICATIONS_DIR}/${launcher_file}" ]]; then
			warn "Desktop shortcut ${launcher_file} remains, but its application is not installed in this container."
		fi
	done
}

main() {
	local owner

	repair_launchers
	warn_about_stale_desktop_shortcuts
	owner="$(resolve_owner)"
	if (( EUID == 0 )); then
		chown -R "${owner}" "${USER_APPLICATIONS_DIR}"
		[[ ! -d "${DESKTOP_DIR}" ]] || chown -R "${owner}" "${DESKTOP_DIR}"
	fi

	if command -v update-desktop-database >/dev/null 2>&1; then
		update-desktop-database "${USER_APPLICATIONS_DIR}" || true
	fi
}

main "$@"
