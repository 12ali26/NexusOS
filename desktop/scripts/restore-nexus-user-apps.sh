#!/usr/bin/env bash

set -Eeuo pipefail

readonly CONFIG_ROOT="${NEXUS_DESKTOP_CONFIG_ROOT:-/config}"
readonly PACKAGE_DIR="${CONFIG_ROOT}/nexus/packages"
readonly APT_PACKAGE_FILE="${CONFIG_ROOT}/nexus/apt-packages.txt"
readonly LOG_DIR="${CONFIG_ROOT}/nexus/logs"
readonly LOG_FILE="${LOG_DIR}/app-restore.log"

log() {
	printf '[Nexus App Restore] %s\n' "$*" | tee -a "${LOG_FILE}"
}

warn() {
	printf '[Nexus App Restore] WARNING: %s\n' "$*" | tee -a "${LOG_FILE}" >&2
}

package_is_installed() {
	local deb_path="$1"
	local package_name

	package_name="$(dpkg-deb --field "${deb_path}" Package 2>/dev/null || true)"
	[[ -n "${package_name}" ]] && dpkg-query --show "${package_name}" >/dev/null 2>&1
}

read_missing_apt_packages() {
	local package_name
	local -A seen_packages=()

	[[ -f "${APT_PACKAGE_FILE}" ]] || return 0
	while IFS= read -r package_name; do
		[[ -n "${package_name}" && "${package_name}" != \#* ]] || continue
		[[ -z "${seen_packages[${package_name}]:-}" ]] || continue
		seen_packages["${package_name}"]=1
		if ! dpkg-query --show "${package_name}" >/dev/null 2>&1; then
			printf '%s\n' "${package_name}"
		fi
	done <"${APT_PACKAGE_FILE}"
}

main() {
	local deb_path
	local -a missing_apt_packages=()
	local -a missing_packages=()
	local restore_failed=0
	local restored=0

	mkdir -p "${PACKAGE_DIR}" "${LOG_DIR}"
	touch "${LOG_FILE}"
	mapfile -t missing_apt_packages < <(read_missing_apt_packages)

	for deb_path in "${PACKAGE_DIR}"/*.deb; do
		[[ -f "${deb_path}" ]] || continue
		if package_is_installed "${deb_path}"; then
			log "Already installed: ${deb_path##*/}"
			continue
		fi
		missing_packages+=("${deb_path}")
	done

	if ((${#missing_packages[@]} > 0 || ${#missing_apt_packages[@]} > 0)); then
		log "Refreshing apt metadata before restoring persisted packages..."
		if ! apt-get update 2>&1 | tee -a "${LOG_FILE}"; then
			warn "Could not refresh apt metadata. Package restore will continue with the available cache."
		fi
	fi

	if ((${#missing_apt_packages[@]} > 0)); then
		log "Restoring persisted apt packages: ${missing_apt_packages[*]}"
		if DEBIAN_FRONTEND=noninteractive apt-get install -y "${missing_apt_packages[@]}" 2>&1 |
			tee -a "${LOG_FILE}"; then
			restored=1
		else
			restore_failed=1
			warn "Could not restore one or more apt packages. Nexus Desktop will continue starting."
		fi
	fi

	for deb_path in "${missing_packages[@]}"; do
		log "Restoring persisted package: ${deb_path##*/}"
		if DEBIAN_FRONTEND=noninteractive apt-get install -y "${deb_path}" 2>&1 |
			tee -a "${LOG_FILE}"; then
			restored=1
		else
			restore_failed=1
			warn "Could not restore ${deb_path##*/}. Nexus Desktop will continue starting."
		fi
	done

	if (( restored == 1 )) && command -v update-desktop-database >/dev/null 2>&1; then
		update-desktop-database 2>&1 | tee -a "${LOG_FILE}" || true
	fi
	if (( restore_failed == 1 )); then
		warn "Some persisted applications could not be restored. Review ${LOG_FILE}."
	else
		log "Persisted application restore check complete."
	fi
}

main "$@"
