#!/usr/bin/env bash

set -Eeuo pipefail

readonly CONFIG_ROOT="${NEXUS_DESKTOP_CONFIG_ROOT:-/config}"
readonly USER_APPLICATIONS_DIR="${CONFIG_ROOT}/.local/share/applications"
readonly MIMEAPPS_FILE="${USER_APPLICATIONS_DIR}/mimeapps.list"
readonly THUNAR_CONFIG_DIR="${CONFIG_ROOT}/.config/Thunar"
readonly THUNAR_UCA_FILE="${THUNAR_CONFIG_DIR}/uca.xml"
readonly OPEN_IN_EDITOR_SCRIPT="${CONFIG_ROOT}/nexus/scripts/nexus-open-in-editor.sh"
readonly INSTALL_SELECTED_SCRIPT="${CONFIG_ROOT}/nexus/scripts/nexus-install-selected-app.sh"
readonly OPEN_IN_EDITOR_ACTION_ID="nexus-open-in-editor-v1"
readonly INSTALL_SELECTED_ACTION_ID="nexus-install-selected-app-v1"

log() {
	printf '[Nexus Desktop Defaults] %s\n' "$*"
}

warn() {
	printf '[Nexus Desktop Defaults] WARNING: %s\n' "$*" >&2
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

launcher_exists() {
	local launcher="$1"

	[[ -f "${USER_APPLICATIONS_DIR}/${launcher}" ]] ||
		[[ -f "/usr/share/applications/${launcher}" ]]
}

current_default_exists() {
	local mime_type="$1"
	local current_default

	current_default="$(HOME="${CONFIG_ROOT}" XDG_DATA_HOME="${CONFIG_ROOT}/.local/share" \
		xdg-mime query default "${mime_type}" 2>/dev/null || true)"
	[[ -n "${current_default}" ]] && launcher_exists "${current_default}"
}

set_default_if_missing() {
	local mime_type="$1"
	local launcher="$2"

	launcher_exists "${launcher}" || return 0
	if current_default_exists "${mime_type}"; then
		return 0
	fi

	log "Setting default ${mime_type} -> ${launcher}"
	HOME="${CONFIG_ROOT}" XDG_DATA_HOME="${CONFIG_ROOT}/.local/share" \
		xdg-mime default "${launcher}" "${mime_type}" ||
		warn "Could not set default application for ${mime_type}."
}

choose_editor_launcher() {
	local launcher

	for launcher in codium.desktop code.desktop cursor.desktop; do
		launcher_exists "${launcher}" && {
			printf '%s\n' "${launcher}"
			return 0
		}
	done
	return 1
}

configure_editor_defaults() {
	local editor_launcher
	local mime_type
	local -a editor_mime_types=(
		text/plain
		text/markdown
		text/html
		text/css
		text/yaml
		text/x-python
		text/x-shellscript
		application/json
		application/x-yaml
		application/xml
		application/javascript
		application/typescript
	)

	editor_launcher="$(choose_editor_launcher || true)"
	[[ -n "${editor_launcher}" ]] || {
		log "No coding editor launcher is installed yet."
		return 0
	}

	for mime_type in "${editor_mime_types[@]}"; do
		set_default_if_missing "${mime_type}" "${editor_launcher}"
	done
}

configure_file_manager_defaults() {
	local launcher="thunar.desktop"
	local mime_type
	local -a folder_mime_types=(
		inode/directory
		x-scheme-handler/file
	)

	for mime_type in "${folder_mime_types[@]}"; do
		set_default_if_missing "${mime_type}" "${launcher}"
	done
}

ensure_thunar_uca_root() {
	mkdir -p "${THUNAR_CONFIG_DIR}"
	if [[ ! -f "${THUNAR_UCA_FILE}" ]]; then
		cat >"${THUNAR_UCA_FILE}" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<actions>
</actions>
EOF
	fi
}

install_thunar_action() {
	local action_id="$1"
	local action_name="$2"
	local action_command="$3"
	local action_description="$4"
	local action_range="$5"
	local action_patterns="$6"
	local temporary_file

	ensure_thunar_uca_root
	if grep -Fq "<unique-id>${action_id}</unique-id>" "${THUNAR_UCA_FILE}"; then
		return 0
	fi

	log "Adding Thunar action: ${action_name}"
	temporary_file="$(mktemp)"
	awk -v command="${action_command}" \
		-v action_id="${action_id}" \
		-v name="${action_name}" \
		-v description="${action_description}" \
		-v range="${action_range}" \
		-v patterns="${action_patterns}" '
		/<\/actions>/ && inserted == 0 {
			print "  <action>"
			print "    <icon>applications-system</icon>"
			print "    <name>" name "</name>"
			print "    <submenu>Nexus</submenu>"
			print "    <unique-id>" action_id "</unique-id>"
			print "    <command>" command "</command>"
			print "    <description>" description "</description>"
			print "    <range>" range "</range>"
			print "    <patterns>" patterns "</patterns>"
			print "    <directories/>"
			print "    <text-files/>"
			print "    <other-files/>"
			print "  </action>"
			inserted = 1
		}
		{ print }
		END {
			if (inserted == 0) {
				print "<actions>"
				print "  <action>"
				print "    <icon>applications-system</icon>"
				print "    <name>" name "</name>"
				print "    <submenu>Nexus</submenu>"
				print "    <unique-id>" action_id "</unique-id>"
				print "    <command>" command "</command>"
				print "    <description>" description "</description>"
				print "    <range>" range "</range>"
				print "    <patterns>" patterns "</patterns>"
				print "    <directories/>"
				print "    <text-files/>"
				print "    <other-files/>"
				print "  </action>"
				print "</actions>"
			}
		}
	' "${THUNAR_UCA_FILE}" >"${temporary_file}"
	install -m 0644 "${temporary_file}" "${THUNAR_UCA_FILE}"
	rm -f "${temporary_file}"
}

install_thunar_actions() {
	if [[ -x "${OPEN_IN_EDITOR_SCRIPT}" ]]; then
		install_thunar_action \
			"${OPEN_IN_EDITOR_ACTION_ID}" \
			"Open in Nexus Editor" \
			"bash ${OPEN_IN_EDITOR_SCRIPT} %F" \
			"Open selected files or folders in the first available Nexus coding editor" \
			"*" \
			"*"
	else
		log "Editor open helper is unavailable; skipping Thunar editor action."
	fi

	if [[ -x "${INSTALL_SELECTED_SCRIPT}" ]]; then
		install_thunar_action \
			"${INSTALL_SELECTED_ACTION_ID}" \
			"Install with Nexus" \
			"bash ${INSTALL_SELECTED_SCRIPT} %f" \
			"Install one selected .deb or AppImage file with Nexus helpers" \
			"1" \
			"*.deb;*.AppImage;*.appimage"
	else
		log "Selected app install helper is unavailable; skipping Thunar install action."
	fi
}

main() {
	local owner

	if ! command -v xdg-mime >/dev/null 2>&1; then
		warn "xdg-mime is unavailable; skipping default application setup."
		return 0
	fi

	mkdir -p "${USER_APPLICATIONS_DIR}"
	configure_file_manager_defaults
	configure_editor_defaults
	install_thunar_actions

	if command -v update-desktop-database >/dev/null 2>&1; then
		update-desktop-database "${USER_APPLICATIONS_DIR}" || true
	fi

	owner="$(resolve_owner)"
	if ((EUID == 0)); then
		chown -R "${owner}" "${USER_APPLICATIONS_DIR}"
		chown -R "${owner}" "${THUNAR_CONFIG_DIR}"
	fi
	log "Default application check complete."
}

main "$@"
