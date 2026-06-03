#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TMP_ROOT=""

log() {
	printf '[Nexus Desktop Helper Test] %s\n' "$*"
}

fail() {
	printf '[Nexus Desktop Helper Test] ERROR: %s\n' "$*" >&2
	exit 1
}

assert_file() {
	[[ -f "$1" ]] || fail "Expected file: $1"
}

assert_executable() {
	[[ -x "$1" ]] || fail "Expected executable: $1"
}

assert_contains() {
	local file_path="$1"
	local pattern="$2"

	grep -Fq -- "${pattern}" "${file_path}" ||
		fail "Expected ${file_path} to contain: ${pattern}"
}

make_root() {
	TMP_ROOT="$(mktemp -d)"
	trap '[[ -z "${TMP_ROOT}" ]] || rm -rf "${TMP_ROOT}"' EXIT
	mkdir -p \
		"${TMP_ROOT}/bin" \
		"${TMP_ROOT}/config/Desktop" \
		"${TMP_ROOT}/config/Downloads" \
		"${TMP_ROOT}/config/nexus/scripts" \
		"${TMP_ROOT}/system"
	cp "${SCRIPT_DIR}/"*.sh "${TMP_ROOT}/config/nexus/scripts/"
	chmod 0755 "${TMP_ROOT}/config/nexus/scripts/"*.sh
}

write_xdg_mime_stub() {
	cat >"${TMP_ROOT}/bin/xdg-mime" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
mimeapps="${XDG_DATA_HOME}/applications/mimeapps.list"
case "$1" in
	query)
		sed -n "s|^$3=||p" "${mimeapps}" 2>/dev/null | head -n 1
		;;
	default)
		launcher="$2"
		mime="$3"
		mkdir -p "$(dirname "${mimeapps}")"
		touch "${mimeapps}"
		if grep -q "^${mime}=" "${mimeapps}"; then
			sed -i "s|^${mime}=.*|${mime}=${launcher}|" "${mimeapps}"
		else
			printf '%s=%s\n' "${mime}" "${launcher}" >>"${mimeapps}"
		fi
		;;
	*)
		exit 2
		;;
esac
EOF
	chmod 0755 "${TMP_ROOT}/bin/xdg-mime"
}

test_launcher_repair() {
	local launcher="${TMP_ROOT}/config/.local/share/applications/cursor.desktop"
	local before after

	log "Testing Electron launcher repair..."
	mkdir -p "${TMP_ROOT}/config/nexus" "${TMP_ROOT}/system"
	cat >"${TMP_ROOT}/system/cursor.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Cursor
Exec=/usr/share/cursor/cursor %F
Icon=cursor
EOF
	printf '#!/usr/bin/env bash\n' >"${TMP_ROOT}/bin/cursor"
	chmod 0755 "${TMP_ROOT}/bin/cursor"
	printf '%s\n' '--ozone-platform=x11' >"${TMP_ROOT}/config/nexus/electron-flags.conf"

	PATH="${TMP_ROOT}/bin:${PATH}" \
		NEXUS_DESKTOP_CONFIG_ROOT="${TMP_ROOT}/config" \
		NEXUS_DESKTOP_SYSTEM_APPLICATIONS_DIR="${TMP_ROOT}/system" \
		NEXUS_DESKTOP_OWNER="$(id -u):$(id -g)" \
		bash "${SCRIPT_DIR}/fix-electron-launchers.sh" >/dev/null

	assert_file "${launcher}"
	assert_contains "${launcher}" "Exec=env GTK_USE_PORTAL=0 ${TMP_ROOT}/bin/cursor"
	assert_contains "${launcher}" "--no-sandbox"
	assert_contains "${launcher}" "--disable-gpu"
	assert_contains "${launcher}" "--xdg-portal-required-version=999"
	assert_contains "${launcher}" "--ozone-platform=x11"

	before="$(sha256sum "${launcher}" | awk '{print $1}')"
	PATH="${TMP_ROOT}/bin:${PATH}" \
		NEXUS_DESKTOP_CONFIG_ROOT="${TMP_ROOT}/config" \
		NEXUS_DESKTOP_SYSTEM_APPLICATIONS_DIR="${TMP_ROOT}/system" \
		NEXUS_DESKTOP_OWNER="$(id -u):$(id -g)" \
		bash "${SCRIPT_DIR}/fix-electron-launchers.sh" >/dev/null
	after="$(sha256sum "${launcher}" | awk '{print $1}')"
	[[ "${before}" == "${after}" ]] || fail "Launcher repair is not idempotent."
}

test_defaults_and_thunar_action() {
	local mimeapps="${TMP_ROOT}/config/.local/share/applications/mimeapps.list"
	local uca="${TMP_ROOT}/config/.config/Thunar/uca.xml"

	log "Testing default associations and Thunar action..."
	write_xdg_mime_stub
	cat >"${TMP_ROOT}/config/.local/share/applications/codium.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=VSCodium
Exec=codium %F
EOF
	cat >"${TMP_ROOT}/config/.local/share/applications/thunar.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Thunar
Exec=thunar %F
EOF

	PATH="${TMP_ROOT}/bin:${PATH}" \
		NEXUS_DESKTOP_CONFIG_ROOT="${TMP_ROOT}/config" \
		NEXUS_DESKTOP_OWNER="$(id -u):$(id -g)" \
		bash "${SCRIPT_DIR}/configure-desktop-defaults.sh" >/dev/null

	assert_contains "${mimeapps}" "inode/directory=thunar.desktop"
	assert_contains "${mimeapps}" "text/plain=codium.desktop"
	assert_contains "${mimeapps}" "application/json=codium.desktop"
	assert_contains "${uca}" "Open in Nexus Editor"
	assert_contains "${uca}" "nexus-open-in-editor.sh %F"
	assert_contains "${uca}" "Install with Nexus"
	assert_contains "${uca}" "nexus-install-selected-app.sh %f"
}

test_open_in_editor() {
	local capture="${TMP_ROOT}/capture"

	log "Testing Open in Nexus Editor helper..."
	cat >"${TMP_ROOT}/bin/codium" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" >"${NEXUS_CAPTURE}"
EOF
	chmod 0755 "${TMP_ROOT}/bin/codium"
	PATH="${TMP_ROOT}/bin:${PATH}" \
		NEXUS_CAPTURE="${capture}" \
		NEXUS_DESKTOP_CONFIG_ROOT="${TMP_ROOT}/config" \
		bash "${SCRIPT_DIR}/nexus-open-in-editor.sh" "${TMP_ROOT}/config/Workspace"
	sleep 1
	assert_contains "${capture}" "--no-sandbox"
	assert_contains "${capture}" "--disable-gpu"
	assert_contains "${capture}" "${TMP_ROOT}/config/Workspace"
}

test_set_default_app() {
	local mimeapps="${TMP_ROOT}/config/.local/share/applications/mimeapps.list"

	log "Testing set-default helper..."
	PATH="${TMP_ROOT}/bin:${PATH}" \
		NEXUS_DESKTOP_CONFIG_ROOT="${TMP_ROOT}/config" \
		NEXUS_DESKTOP_SYSTEM_APPLICATIONS_DIR="${TMP_ROOT}/system" \
		NEXUS_DESKTOP_OWNER="$(id -u):$(id -g)" \
		bash "${SCRIPT_DIR}/nexus-set-default-app.sh" cursor text/markdown >/dev/null

	assert_contains "${mimeapps}" "text/markdown=cursor.desktop"
}

test_appimage_install() {
	local launcher="${TMP_ROOT}/config/.local/share/applications/nexus-test-editor.desktop"
	local appimage="${TMP_ROOT}/config/nexus/appimages/nexus-test-editor.AppImage"

	log "Testing AppImage registration..."
	printf '#!/bin/sh\n' >"${TMP_ROOT}/config/Downloads/TestEditor.AppImage"
	chmod 0755 "${TMP_ROOT}/config/Downloads/TestEditor.AppImage"

	PATH="${TMP_ROOT}/bin:${PATH}" \
		NEXUS_DESKTOP_CONFIG_ROOT="${TMP_ROOT}/config" \
		NEXUS_DESKTOP_OWNER="$(id -u):$(id -g)" \
		bash "${SCRIPT_DIR}/nexus-install-appimage.sh" \
		--name "Test Editor" \
		--electron \
		"${TMP_ROOT}/config/Downloads/TestEditor.AppImage" >/dev/null

	assert_executable "${appimage}"
	assert_contains "${launcher}" "Exec=env GTK_USE_PORTAL=0 ${appimage}"
	assert_contains "${launcher}" "--no-sandbox"
}

test_selected_app_installer() {
	local capture="${TMP_ROOT}/selected-capture"
	local deb_file="${TMP_ROOT}/config/Downloads/example.deb"
	local appimage_file="${TMP_ROOT}/config/Downloads/example.AppImage"

	log "Testing selected app installer dispatcher..."
	cat >"${TMP_ROOT}/config/nexus/scripts/nexus-install-deb.sh" <<'EOF'
#!/usr/bin/env bash
printf 'deb:%s\n' "$1" >>"${NEXUS_CAPTURE}"
EOF
	cat >"${TMP_ROOT}/config/nexus/scripts/nexus-install-appimage.sh" <<'EOF'
#!/usr/bin/env bash
printf 'appimage:%s\n' "$1" >>"${NEXUS_CAPTURE}"
EOF
	chmod 0755 \
		"${TMP_ROOT}/config/nexus/scripts/nexus-install-deb.sh" \
		"${TMP_ROOT}/config/nexus/scripts/nexus-install-appimage.sh"
	printf 'deb' >"${deb_file}"
	printf '#!/bin/sh\n' >"${appimage_file}"

	NEXUS_CAPTURE="${capture}" \
		NEXUS_DESKTOP_CONFIG_ROOT="${TMP_ROOT}/config" \
		bash "${SCRIPT_DIR}/nexus-install-selected-app.sh" "${deb_file}"
	NEXUS_CAPTURE="${capture}" \
		NEXUS_DESKTOP_CONFIG_ROOT="${TMP_ROOT}/config" \
		bash "${SCRIPT_DIR}/nexus-install-selected-app.sh" "${appimage_file}"

	assert_contains "${capture}" "deb:${deb_file}"
	assert_contains "${capture}" "appimage:${appimage_file}"
}

test_register_app() {
	local tool="${TMP_ROOT}/config/Shared/my-tool"
	local launcher="${TMP_ROOT}/config/.local/share/applications/nexus-my-tool.desktop"

	log "Testing generic app registration..."
	mkdir -p "${TMP_ROOT}/config/Shared"
	printf '#!/usr/bin/env bash\n' >"${TMP_ROOT}/bin/codium"
	chmod 0755 "${TMP_ROOT}/bin/codium"
	printf '#!/usr/bin/env bash\n' >"${tool}"
	chmod 0755 "${tool}"

	PATH="${TMP_ROOT}/bin:${PATH}" \
		NEXUS_DESKTOP_CONFIG_ROOT="${TMP_ROOT}/config" \
		NEXUS_DESKTOP_OWNER="$(id -u):$(id -g)" \
		bash "${SCRIPT_DIR}/nexus-register-app.sh" --name "My Tool" --electron "${tool}" >/dev/null

	assert_contains "${launcher}" "Name=My Tool"
	assert_contains "${launcher}" "Exec=env GTK_USE_PORTAL=0 ${tool}"
	assert_contains "${launcher}" "--no-sandbox"
	assert_contains "${launcher}" "--disable-gpu"
}

test_desktop_doctor() {
	local output="${TMP_ROOT}/doctor.out"

	log "Testing desktop doctor..."
	cat >"${TMP_ROOT}/config/.local/share/applications/broken.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Broken
Exec=/missing/app %F
EOF
	printf 'vlc\n' >"${TMP_ROOT}/config/nexus/apt-packages.txt"
	printf 'deb' >"${TMP_ROOT}/config/nexus/packages/sample.deb"

	PATH="${TMP_ROOT}/bin:${PATH}" \
		NEXUS_DESKTOP_CONFIG_ROOT="${TMP_ROOT}/config" \
		bash "${SCRIPT_DIR}/nexus-desktop-doctor.sh" >"${output}"

	assert_contains "${output}" "apt: vlc"
	assert_contains "${output}" "deb: sample.deb"
	assert_contains "${output}" "broken.desktop [missing executable]"
	assert_contains "${output}" "Open in Nexus Editor"
}

test_restore_user_apps() {
	local restore_capture="${TMP_ROOT}/restore-capture"

	log "Testing persisted app restore hook..."
	printf 'demo-package\n' >"${TMP_ROOT}/config/nexus/apt-packages.txt"
	cat >"${TMP_ROOT}/bin/dpkg-query" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
	cat >"${TMP_ROOT}/bin/apt-get" <<'EOF'
#!/usr/bin/env bash
printf 'apt-get:%s\n' "$*" >>"${NEXUS_RESTORE_CAPTURE}"
exit 0
EOF
	chmod 0755 "${TMP_ROOT}/bin/dpkg-query" "${TMP_ROOT}/bin/apt-get"

	PATH="${TMP_ROOT}/bin:${PATH}" \
		NEXUS_RESTORE_CAPTURE="${restore_capture}" \
		NEXUS_DESKTOP_CONFIG_ROOT="${TMP_ROOT}/config" \
		bash "${SCRIPT_DIR}/restore-nexus-user-apps.sh" >/dev/null

	assert_contains "${restore_capture}" "apt-get:update"
	assert_contains "${restore_capture}" "apt-get:install -y demo-package"
}

main() {
	make_root
	mkdir -p "${TMP_ROOT}/config/.local/share/applications" "${TMP_ROOT}/config/nexus/packages"
	test_launcher_repair
	test_defaults_and_thunar_action
	test_open_in_editor
	test_set_default_app
	test_appimage_install
	test_selected_app_installer
	test_register_app
	test_desktop_doctor
	test_restore_user_apps
	log "All helper smoke tests passed."
}

main "$@"
