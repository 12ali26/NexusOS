#!/usr/bin/env bash

set -Eeuo pipefail

readonly CONFIG_ROOT="${NEXUS_DESKTOP_CONFIG_ROOT:-/config}"
readonly SYSTEM_APPLICATIONS_DIR="${NEXUS_DESKTOP_SYSTEM_APPLICATIONS_DIR:-/usr/share/applications}"
readonly USER_APPLICATIONS_DIR="${CONFIG_ROOT}/.local/share/applications"
readonly DESKTOP_DIR="${CONFIG_ROOT}/Desktop"
readonly ELECTRON_LAUNCHER_CONFIG="${CONFIG_ROOT}/nexus/electron-launchers.conf"
readonly ELECTRON_FLAGS_CONFIG="${CONFIG_ROOT}/nexus/electron-flags.conf"
readonly -a KNOWN_ELECTRON_LAUNCHERS=(
	codium.desktop
	codium-url-handler.desktop
	code.desktop
	code-url-handler.desktop
	cursor.desktop
	cursor-url-handler.desktop
)
readonly -a DEFAULT_ELECTRON_FLAGS=(
	--xdg-portal-required-version=999
	--no-sandbox
	--disable-gpu
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

resolve_known_executable() {
	local launcher_file="$1"
	local command_name=""
	local -a candidates=()
	local candidate

	case "${launcher_file}" in
		codium*.desktop)
			command_name="codium"
			candidates=(/usr/share/codium/codium /usr/bin/codium /bin/codium)
			;;
		code*.desktop)
			command_name="code"
			candidates=(/usr/share/code/code /usr/bin/code /bin/code)
			;;
		cursor*.desktop)
			command_name="cursor"
			candidates=(
				/usr/share/cursor/cursor
				/usr/share/Cursor/cursor
				/opt/cursor/cursor
				/opt/Cursor/cursor
				/usr/bin/cursor
				/bin/cursor
			)
			;;
	esac

	if [[ -n "${command_name}" ]]; then
		candidate="$(command -v "${command_name}" 2>/dev/null || true)"
		[[ -n "${candidate}" && -x "${candidate}" ]] && {
			printf '%s\n' "${candidate}"
			return 0
		}
	fi

	for candidate in "${candidates[@]}"; do
		[[ -x "${candidate}" ]] || continue
		printf '%s\n' "${candidate}"
		return 0
	done

	return 1
}

exec_command_exists() {
	local launcher_path="$1"
	local exec_command

	exec_command="$(extract_exec_command "${launcher_path}")"
	[[ -n "${exec_command}" ]] || return 1
	exec_command="${exec_command#\"}"
	exec_command="${exec_command%\"}"

	if [[ "${exec_command}" == /* ]]; then
		[[ -x "${exec_command}" ]]
	else
		command -v "${exec_command}" >/dev/null 2>&1
	fi
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

rewrite_exec_command() {
	local source_file="$1"
	local replacement="$2"
	local destination_file="$3"

	sed -E "
		/^Exec=env([[:space:]]|$)/ {
			s|^(Exec=env([[:space:]]+[[:alnum:]_]+=[^[:space:]]+)*[[:space:]]+)[^[:space:]]+|\\1${replacement}|
		}
		/^Exec=env([[:space:]]|$)/! {
			s|^(Exec=)[^[:space:]]+|\\1${replacement}|
		}
	" "${source_file}" >"${destination_file}"
}

prepare_patch_source() {
	local source_file="$1"
	local launcher_file="$2"
	local prepared_file="$3"
	local replacement

	cp "${source_file}" "${prepared_file}"
	if exec_command_exists "${prepared_file}"; then
		return 0
	fi

	if replacement="$(resolve_known_executable "${launcher_file}")"; then
		log "Repairing launcher executable for ${launcher_file}: ${replacement}"
		rewrite_exec_command "${prepared_file}" "${replacement}" "${prepared_file}.fixed"
		mv "${prepared_file}.fixed" "${prepared_file}"
	fi
}

read_electron_flags() {
	local flag

	for flag in "${DEFAULT_ELECTRON_FLAGS[@]}"; do
		printf '%s\n' "${flag}"
	done

	[[ -f "${ELECTRON_FLAGS_CONFIG}" ]] || return 0
	grep -Ev '^[[:space:]]*(#|$)' "${ELECTRON_FLAGS_CONFIG}" || true
}

add_exec_flag() {
	local source_file="$1"
	local flag="$2"
	local destination_file="$3"

	awk -v flag="${flag}" '
		/^Exec=/ {
			if (index($0, flag) == 0 &&
				match($0, /^Exec=env([[:space:]]+[[:alnum:]_]+=[^[:space:]]+)*[[:space:]]+[^[:space:]]+/)) {
				$0 = substr($0, 1, RLENGTH) " " flag substr($0, RLENGTH + 1)
			}
		}
		{ print }
	' "${source_file}" >"${destination_file}"
}

add_exec_flags() {
	local source_file="$1"
	local destination_file="$2"
	local current_file next_file flag

	current_file="${source_file}"
	while IFS= read -r flag; do
		[[ -n "${flag}" ]] || continue
		next_file="$(mktemp)"
		add_exec_flag "${current_file}" "${flag}" "${next_file}"
		[[ "${current_file}" == "${source_file}" ]] || rm -f "${current_file}"
		current_file="${next_file}"
	done < <(read_electron_flags)

	install -m 0644 "${current_file}" "${destination_file}"
	[[ "${current_file}" == "${source_file}" ]] || rm -f "${current_file}"
}

patch_launcher() {
	local source_file="$1"
	local destination_file="$2"
	local launcher_file="${source_file##*/}"
	local prepared_source
	local temporary_file

	prepared_source="$(mktemp)"
	temporary_file="$(mktemp)"
	prepare_patch_source "${source_file}" "${launcher_file}" "${prepared_source}"
	sed -E '
		/^Exec=/ {
			/^Exec=env([[:space:]]|$)/! s/^Exec=/Exec=env GTK_USE_PORTAL=0 /
			/^Exec=env([[:space:]]|$)/ {
				/(^|[[:space:]])GTK_USE_PORTAL=/! s/^Exec=env/Exec=env GTK_USE_PORTAL=0/
			}
		}
	' "${prepared_source}" >"${temporary_file}"
	add_exec_flags "${temporary_file}" "${destination_file}"
	if ! exec_command_exists "${destination_file}"; then
		warn "Generated launcher still points at a missing executable: ${destination_file}"
	fi
	rm -f "${prepared_source}" "${temporary_file}"
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

	while IFS= read -r -d '' launcher_path; do
		is_electron_launcher "${launcher_path}" || continue
		launcher_file="${launcher_path##*/}"
		log "Repairing container-safe user launcher: ${launcher_file}"
		patch_launcher "${launcher_path}" "${USER_APPLICATIONS_DIR}/${launcher_file}"
		repair_desktop_shortcut "${launcher_file}" "${launcher_path}"
		repaired=1
	done < <(find "${USER_APPLICATIONS_DIR}" -maxdepth 1 -type f -name '*.desktop' -print0 | sort -z)

	if [[ -d "${DESKTOP_DIR}" ]]; then
		while IFS= read -r -d '' launcher_path; do
			launcher_file="${launcher_path##*/}"
			[[ ! -f "${SYSTEM_APPLICATIONS_DIR}/${launcher_file}" ]] || continue
			is_electron_launcher "${launcher_path}" || continue
			log "Repairing user desktop launcher without a system entry: ${launcher_file}"
			patch_launcher "${launcher_path}" "${USER_APPLICATIONS_DIR}/${launcher_file}"
			repair_desktop_shortcut "${launcher_file}" "${launcher_path}"
			repaired=1
		done < <(find "${DESKTOP_DIR}" -maxdepth 1 -type f -name '*.desktop' -print0 | sort -z)
	fi

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
