#!/usr/bin/env bash

deploy_nexus_ui() {
	local build_root="${NEXUS_UI_SOURCE_ROOT:-${NEXUS_INSTALL_ROOT}/UI/build/sysroot/var/lib/casaos/www}"
	local web_root="${NEXUS_WEB_ROOT:-/var/lib/casaos/www}"
	local timestamp
	timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
	export NEXUS_UI_BACKUP="${web_root}.backup-${timestamp}"

	[[ -d "${build_root}" ]] || fail "Frontend build output is missing: ${build_root}."
	[[ -f "${build_root}/index.html" ]] || fail "Frontend build output is invalid: ${build_root}/index.html is missing."

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
	[[ -f "${web_root}/index.html" ]] || fail "Deployed Nexus Cloud UI is invalid: ${web_root}/index.html is missing."

	if [[ "${NEXUS_SKIP_PERMISSIONS:-0}" == "1" ]]; then
		warn "Skipping UI ownership and mode normalization because NEXUS_SKIP_PERMISSIONS=1."
	else
		log "Normalizing Nexus Cloud UI ownership and modes..."
		chown -R root:root "${web_root}"
		find "${web_root}" -type d -exec chmod 755 {} +
		find "${web_root}" -type f -exec chmod 644 {} +
	fi

	if [[ "${NEXUS_SKIP_RESTART:-0}" == "1" ]]; then
		warn "Skipping casaos.service restart because NEXUS_SKIP_RESTART=1."
	elif command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]; then
		restart_casaos_service
	else
		warn "systemd is unavailable. Restart casaos.service manually if your environment provides it."
	fi
}

restart_casaos_service() {
	local restart_failed=0

	log "Restarting casaos.service..."
	systemctl restart casaos || restart_failed=1
	sleep 3

	if systemctl is-active --quiet casaos; then
		if (( restart_failed == 1 )); then
			warn "systemctl restart casaos returned an error, but casaos.service became active after the wait."
		else
			log "casaos.service is active."
		fi
		return
	fi

	printf '[Nexus Cloud] ERROR: casaos.service is not active after restart.\n' >&2
	systemctl status casaos --no-pager -l || true
	journalctl -xeu casaos.service --no-pager -n 80 || true
	fail "casaos.service restart verification failed."
}
