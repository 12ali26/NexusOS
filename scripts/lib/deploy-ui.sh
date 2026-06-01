#!/usr/bin/env bash

deploy_nexus_ui() {
	local build_root="${NEXUS_UI_SOURCE_ROOT:-${NEXUS_INSTALL_ROOT}/UI/build/sysroot/var/lib/casaos/www}"
	local web_root="${NEXUS_WEB_ROOT:-/var/lib/casaos/www}"
	local timestamp
	timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
	export NEXUS_UI_BACKUP="${web_root}.backup-${timestamp}"

	[[ -d "${build_root}" ]] || fail "Frontend build output is missing: ${build_root}."

	if [[ -d "${web_root}" ]]; then
		log "Backing up the current CasaOS UI to ${NEXUS_UI_BACKUP}..."
		cp -a "${web_root}" "${NEXUS_UI_BACKUP}"
	else
		warn "${web_root} does not exist. No existing CasaOS UI was available to back up."
		NEXUS_UI_BACKUP="none"
		export NEXUS_UI_BACKUP
	fi

	log "Deploying the Nexus Cloud UI..."
	mkdir -p "${web_root}"
	rsync -a --delete "${build_root}/" "${web_root}/"

	if [[ "${NEXUS_SKIP_RESTART:-0}" == "1" ]]; then
		warn "Skipping casaos.service restart because NEXUS_SKIP_RESTART=1."
	elif command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]; then
		log "Restarting casaos.service..."
		systemctl restart casaos.service
	else
		warn "systemd is unavailable. Restart casaos.service manually if your environment provides it."
	fi
}
