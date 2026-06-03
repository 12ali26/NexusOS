#!/usr/bin/env bash

set -Eeuo pipefail

readonly CONFIG_ROOT="${NEXUS_DESKTOP_CONFIG_ROOT:-/config}"
readonly USER_APPLICATIONS_DIR="${CONFIG_ROOT}/.local/share/applications"
readonly SYSTEM_APPLICATIONS_DIR="${NEXUS_DESKTOP_SYSTEM_APPLICATIONS_DIR:-/usr/share/applications}"
readonly DESKTOP_DIR="${CONFIG_ROOT}/Desktop"
readonly NEXUS_DIR="${CONFIG_ROOT}/nexus"
readonly PACKAGE_DIR="${NEXUS_DIR}/packages"
readonly APPIMAGE_DIR="${NEXUS_DIR}/appimages"
readonly APT_PACKAGE_FILE="${NEXUS_DIR}/apt-packages.txt"
readonly ELECTRON_LAUNCHER_CONFIG="${NEXUS_DIR}/electron-launchers.conf"
readonly ELECTRON_FLAGS_CONFIG="${NEXUS_DIR}/electron-flags.conf"
readonly EDITOR_CONFIG="${NEXUS_DIR}/editor-command.conf"
readonly LOG_DIR="${NEXUS_DIR}/logs"
readonly THUNAR_UCA_FILE="${CONFIG_ROOT}/.config/Thunar/uca.xml"
readonly OPEN_IN_EDITOR_ACTION_ID="nexus-open-in-editor-v1"
readonly -a DEFAULT_QUERIES=(
	inode/directory
	text/plain
	application/json
	text/markdown
)

section() {
	printf '\n== %s ==\n' "$*"
}

status_line() {
	printf '%-34s %s\n' "$1" "$2"
}

extract_exec_command() {
	local launcher_path="$1"
	local exec_line

	exec_line="$(sed -nE 's/^Exec=([^[:space:]]+).*/\1/p' "${launcher_path}" | head -n 1)"
	[[ "${exec_line}" == "env" ]] &&
		exec_line="$(sed -nE 's/^Exec=env([[:space:]]+[[:alnum:]_]+=[^[:space:]]+)*[[:space:]]+([^[:space:]]+).*/\2/p' "${launcher_path}" | head -n 1)"
	printf '%s\n' "${exec_line}"
}

exec_target_exists() {
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

print_file_if_present() {
	local label="$1"
	local file_path="$2"

	if [[ -f "${file_path}" ]]; then
		status_line "${label}" "${file_path}"
		sed 's/^/  /' "${file_path}"
	else
		status_line "${label}" "not present"
	fi
}

check_helpers() {
	local helper
	local helper_path
	local -a helpers=(
		configure-desktop-defaults.sh
		fix-electron-launchers.sh
		nexus-install-apt.sh
		nexus-install-appimage.sh
		nexus-install-deb.sh
		nexus-install-downloaded-debs.sh
		nexus-open-in-editor.sh
		nexus-set-default-app.sh
		restore-nexus-user-apps.sh
	)

	section "Helper Scripts"
	for helper in "${helpers[@]}"; do
		helper_path="${NEXUS_DIR}/scripts/${helper}"
		if [[ -x "${helper_path}" ]]; then
			status_line "${helper}" "ok"
		elif [[ -f "${helper_path}" ]]; then
			status_line "${helper}" "present but not executable"
		else
			status_line "${helper}" "missing"
		fi
	done
}

check_persistence() {
	section "Persisted Applications"
	status_line "apt package list" "$([[ -f "${APT_PACKAGE_FILE}" ]] && printf present || printf missing)"
	if [[ -f "${APT_PACKAGE_FILE}" ]]; then
		grep -Ev '^[[:space:]]*(#|$)' "${APT_PACKAGE_FILE}" | sed 's/^/  apt: /' || true
	fi
	if [[ -d "${PACKAGE_DIR}" ]]; then
		find "${PACKAGE_DIR}" -maxdepth 1 -type f -name '*.deb' -printf '  deb: %f\n' | sort
	else
		status_line "cached .deb packages" "none"
	fi
	if [[ -d "${APPIMAGE_DIR}" ]]; then
		find "${APPIMAGE_DIR}" -maxdepth 1 -type f -name '*.AppImage' -printf '  appimage: %f\n' | sort
	else
		status_line "registered AppImages" "none"
	fi
}

check_defaults() {
	local mime_type
	local default_app

	section "Default Applications"
	if command -v xdg-mime >/dev/null 2>&1; then
		for mime_type in "${DEFAULT_QUERIES[@]}"; do
			default_app="$(HOME="${CONFIG_ROOT}" XDG_DATA_HOME="${CONFIG_ROOT}/.local/share" \
				xdg-mime query default "${mime_type}" 2>/dev/null || true)"
			status_line "${mime_type}" "${default_app:-unset}"
		done
	else
		status_line "xdg-mime" "unavailable"
	fi
	print_file_if_present "editor command" "${EDITOR_CONFIG}"
}

check_launchers() {
	local launcher_path
	local launcher_file
	local exec_lines
	local target_status

	section "Launchers"
	if [[ ! -d "${USER_APPLICATIONS_DIR}" ]]; then
		status_line "user launchers" "missing directory"
		return 0
	fi

	while IFS= read -r -d '' launcher_path; do
		launcher_file="${launcher_path##*/}"
		exec_lines="$(grep '^Exec=' "${launcher_path}" || true)"
		if exec_target_exists "${launcher_path}"; then
			target_status="ok"
		else
			target_status="missing executable"
		fi
		printf '%s [%s]\n' "${launcher_file}" "${target_status}"
		[[ -z "${exec_lines}" ]] || printf '%s\n' "${exec_lines}" | sed 's/^/  /'
	done < <(find "${USER_APPLICATIONS_DIR}" -maxdepth 1 -type f -name '*.desktop' -print0 | sort -z)

	if [[ -d "${DESKTOP_DIR}" ]]; then
		section "Desktop Shortcuts"
		find "${DESKTOP_DIR}" -maxdepth 1 -type f -name '*.desktop' -printf '%f\n' | sort | sed 's/^/  /'
	fi
}

check_thunar() {
	section "Thunar Actions"
	if [[ -f "${THUNAR_UCA_FILE}" ]] &&
		grep -Fq "<unique-id>${OPEN_IN_EDITOR_ACTION_ID}</unique-id>" "${THUNAR_UCA_FILE}"; then
		status_line "Open in Nexus Editor" "installed"
		grep -A4 -B2 -F "<unique-id>${OPEN_IN_EDITOR_ACTION_ID}</unique-id>" "${THUNAR_UCA_FILE}" | sed 's/^/  /'
	else
		status_line "Open in Nexus Editor" "missing"
	fi
}

check_configs() {
	section "Compatibility Config"
	print_file_if_present "electron launchers" "${ELECTRON_LAUNCHER_CONFIG}"
	print_file_if_present "electron flags" "${ELECTRON_FLAGS_CONFIG}"
}

check_logs() {
	local log_file

	section "Recent Logs"
	for log_file in "${LOG_DIR}/app-install.log" "${LOG_DIR}/app-restore.log"; do
		if [[ -f "${log_file}" ]]; then
			printf '%s\n' "${log_file}"
			tail -40 "${log_file}" | sed 's/^/  /'
		else
			status_line "${log_file}" "missing"
		fi
	done
}

main() {
	check_helpers
	check_persistence
	check_defaults
	check_launchers
	check_thunar
	check_configs
	check_logs
}

main "$@"
