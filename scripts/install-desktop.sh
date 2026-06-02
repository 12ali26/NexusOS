#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_SOURCE="${BASH_SOURCE[0]:-}"
readonly SCRIPT_DIR="$(cd "$(dirname "${SCRIPT_SOURCE:-.}")" 2>/dev/null && pwd || pwd)"
readonly REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly DESKTOP_DIR="${REPO_ROOT}/desktop"
readonly COMPOSE_FILE="${DESKTOP_DIR}/docker-compose.yml"
readonly NEXUS_NETWORK="nexus-network"
readonly NEXUS_DATA_ROOT="/DATA/Nexus"

log() {
	printf '[Nexus Desktop] %s\n' "$*"
}

warn() {
	printf '[Nexus Desktop] WARNING: %s\n' "$*" >&2
}

fail() {
	printf '[Nexus Desktop] ERROR: %s\n' "$*" >&2
	exit 1
}

require_root() {
	if (( EUID == 0 )); then
		return
	fi

	if [[ -f "${SCRIPT_SOURCE}" ]] && command -v sudo >/dev/null 2>&1; then
		log "Requesting sudo privileges..."
		exec sudo -E bash "${SCRIPT_SOURCE}" "$@"
	fi

	fail "Run this installer with sudo: sudo bash scripts/install-desktop.sh"
}

require_docker() {
	command -v docker >/dev/null 2>&1 ||
		fail "Docker is required. Install Docker before running this desktop installer."
	docker compose version >/dev/null 2>&1 ||
		fail "The Docker Compose plugin is required. Install it before running this desktop installer."
	[[ -f "${COMPOSE_FILE}" ]] ||
		fail "Cannot find ${COMPOSE_FILE}. Run this script from a NexusOS repository checkout."
}

create_persistent_folders() {
	log "Creating persistent Nexus folders under ${NEXUS_DATA_ROOT}..."
	mkdir -p \
		"${NEXUS_DATA_ROOT}/Home" \
		"${NEXUS_DATA_ROOT}/Workspace" \
		"${NEXUS_DATA_ROOT}/Downloads" \
		"${NEXUS_DATA_ROOT}/Shared"
	chown -R 1000:1000 "${NEXUS_DATA_ROOT}"
}

create_network_if_missing() {
	if docker network inspect "${NEXUS_NETWORK}" >/dev/null 2>&1; then
		log "Docker network ${NEXUS_NETWORK} already exists."
	else
		log "Creating Docker network ${NEXUS_NETWORK}..."
		docker network create "${NEXUS_NETWORK}" >/dev/null
	fi
}

start_desktop() {
	log "Starting Nexus Desktop..."
	(
		cd "${DESKTOP_DIR}"
		docker compose up -d
	)
}

print_summary() {
	printf '\nNexus Desktop is starting.\n'
	printf 'Open this URL after the container becomes healthy:\n'
	printf 'https://SERVER_IP:6901\n'
	printf '\nDetected local URLs:\n'
	printf 'https://localhost:6901\n'

	local ip
	for ip in $(hostname -I 2>/dev/null || true); do
		if [[ "${ip}" == *.* ]] && [[ "${ip}" != "127."* ]]; then
			printf 'https://%s:6901\n' "${ip}"
		fi
	done

	printf '\n'
	warn "Your browser may show a self-signed certificate warning during this prototype milestone."
	warn "Restrict TCP port 6901 to your own IP address in the server firewall or cloud security group."
}

main() {
	require_root "$@"
	require_docker
	create_persistent_folders
	create_network_if_missing
	start_desktop
	print_summary
}

main "$@"
