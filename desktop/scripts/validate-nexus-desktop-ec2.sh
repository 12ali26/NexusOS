#!/usr/bin/env bash

set -Eeuo pipefail

readonly TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
readonly LOG_FILE="${NEXUS_DESKTOP_VALIDATION_LOG:-nexus-desktop-validation-${TIMESTAMP}.log}"

log() {
	printf '[Nexus Desktop EC2 Validate] %s\n' "$*" | tee -a "${LOG_FILE}"
}

run_check() {
	local description="$1"
	shift

	log ""
	log "## ${description}"
	printf '$ %s\n' "$*" | tee -a "${LOG_FILE}"
	if "$@" 2>&1 | tee -a "${LOG_FILE}"; then
		log "PASS: ${description}"
	else
		log "FAIL: ${description}"
		return 1
	fi
}

run_optional() {
	local description="$1"
	shift

	log ""
	log "## ${description}"
	printf '$ %s\n' "$*" | tee -a "${LOG_FILE}"
	if "$@" 2>&1 | tee -a "${LOG_FILE}"; then
		log "PASS: ${description}"
	else
		log "WARN: ${description}"
	fi
}

main() {
	local failed=0

	: >"${LOG_FILE}"
	log "Writing validation log to ${LOG_FILE}"
	run_check "Container is running" docker ps --filter name=nexus-desktop || failed=1
	run_check "Workspace folder exists" docker exec nexus-desktop test -d /config/Workspace || failed=1
	run_check "Downloads folder exists" docker exec nexus-desktop test -d /config/Downloads || failed=1
	run_check "Shared folder exists" docker exec nexus-desktop test -d /config/Shared || failed=1
	run_check "Nexus helper smoke test inside container" docker exec -u abc nexus-desktop bash /config/nexus/scripts/nexus-desktop-doctor.sh || failed=1

	run_optional "VSCodium launcher Exec lines" docker exec -u abc nexus-desktop grep '^Exec=' /config/.local/share/applications/codium.desktop
	run_optional "Cursor launcher Exec lines" docker exec -u abc nexus-desktop grep '^Exec=' /config/.local/share/applications/cursor.desktop
	run_optional "Directory default app" docker exec -u abc nexus-desktop xdg-mime query default inode/directory
	run_optional "Text default app" docker exec -u abc nexus-desktop xdg-mime query default text/plain
	run_optional "App install log tail" docker exec nexus-desktop tail -100 /config/nexus/logs/app-install.log
	run_optional "App restore log tail" docker exec nexus-desktop tail -100 /config/nexus/logs/app-restore.log
	run_optional "Recent container logs" docker logs nexus-desktop --tail 120

	log ""
	if ((failed == 0)); then
		log "Host-side validation completed. Continue with browser checks in desktop/NEXUS_DESKTOP_EC2_VALIDATION.md."
	else
		log "Host-side validation found failures. Review ${LOG_FILE} before browser checks."
	fi
	exit "${failed}"
}

main "$@"
