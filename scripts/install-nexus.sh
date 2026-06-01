#!/usr/bin/env bash

set -Eeuo pipefail

readonly NEXUS_REPOSITORY_URL="${NEXUS_REPOSITORY_URL:-https://github.com/12ali26/NexusOS.git}"
readonly NEXUS_BRANCH="${NEXUS_BRANCH:-main}"
readonly NEXUS_INSTALL_ROOT="${NEXUS_INSTALL_ROOT:-/opt/nexusos}"
readonly SCRIPT_SOURCE="${BASH_SOURCE[0]:-}"
readonly SCRIPT_DIR="$(cd "$(dirname "${SCRIPT_SOURCE:-.}")" 2>/dev/null && pwd || pwd)"
readonly LIB_DIR="${SCRIPT_DIR}/lib"

log() {
	printf '[Nexus Cloud] %s\n' "$*"
}

warn() {
	printf '[Nexus Cloud] WARNING: %s\n' "$*" >&2
}

fail() {
	printf '[Nexus Cloud] ERROR: %s\n' "$*" >&2
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

	fail "Run this installer as root. For the one-line install, pipe it to 'sudo bash'."
}

install_bootstrap_dependencies() {
	[[ -r /etc/os-release ]] || fail "Cannot detect Linux distribution: /etc/os-release is missing."
	# shellcheck source=/dev/null
	source /etc/os-release

	local distro_words=" ${ID:-} ${ID_LIKE:-} "
	if [[ "${distro_words}" == *" debian "* ]] || [[ "${distro_words}" == *" ubuntu "* ]] || [[ "${distro_words}" == *" raspbian "* ]]; then
		apt-get update
		DEBIAN_FRONTEND=noninteractive apt-get install -y curl git ca-certificates rsync
		return
	fi

	if [[ "${distro_words}" == *" rhel "* ]] || [[ "${distro_words}" == *" fedora "* ]] || [[ "${distro_words}" == *" centos "* ]]; then
		warn "CentOS/RHEL/Fedora support is experimental and has not been validated yet."
		local package_manager
		package_manager="$(command -v dnf || command -v yum || true)"
		[[ -n "${package_manager}" ]] || fail "Neither dnf nor yum is available."
		"${package_manager}" install -y curl git ca-certificates rsync
		return
	fi

	fail "Unsupported Linux distribution: ${ID:-unknown} (${ID_LIKE:-no ID_LIKE value})."
}

update_checkout() {
	if [[ ! -d "${NEXUS_INSTALL_ROOT}/.git" ]]; then
		log "Cloning NexusOS into ${NEXUS_INSTALL_ROOT}..."
		git clone --branch "${NEXUS_BRANCH}" --single-branch "${NEXUS_REPOSITORY_URL}" "${NEXUS_INSTALL_ROOT}"
		return
	fi

	if ! git -C "${NEXUS_INSTALL_ROOT}" diff --quiet || ! git -C "${NEXUS_INSTALL_ROOT}" diff --cached --quiet; then
		fail "${NEXUS_INSTALL_ROOT} has tracked local changes. Commit or remove them before updating."
	fi

	local current_branch
	current_branch="$(git -C "${NEXUS_INSTALL_ROOT}" branch --show-current)"
	[[ "${current_branch}" == "${NEXUS_BRANCH}" ]] || fail "${NEXUS_INSTALL_ROOT} must be on branch ${NEXUS_BRANCH}; found ${current_branch:-detached HEAD}."

	log "Updating ${NEXUS_INSTALL_ROOT} with fast-forward-only Git semantics..."
	git -C "${NEXUS_INSTALL_ROOT}" fetch origin "${NEXUS_BRANCH}"
	git -C "${NEXUS_INSTALL_ROOT}" merge --ff-only "origin/${NEXUS_BRANCH}"
}

bootstrap_checkout() {
	log "Preparing the NexusOS checkout..."
	install_bootstrap_dependencies
	update_checkout

	local checked_out_installer="${NEXUS_INSTALL_ROOT}/scripts/install-nexus.sh"
	[[ -f "${checked_out_installer}" ]] || fail "The checked-out repository does not contain ${checked_out_installer}."
	exec env NEXUS_SKIP_UPDATE=1 bash "${checked_out_installer}"
}

provision_node() {
	local node_major=0
	if command -v node >/dev/null 2>&1; then
		node_major="$(node --version | sed -E 's/^v([0-9]+).*/\1/')"
	fi

	if (( node_major < 22 )); then
		log "Installing Node.js 22 LTS for the frontend build..."
		case "${NEXUS_OS_FAMILY}" in
			debian)
				curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
				DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs
				;;
			rhel)
				curl -fsSL https://rpm.nodesource.com/setup_22.x | bash -
				"${NEXUS_PACKAGE_MANAGER}" install -y nodejs
				;;
			*)
				fail "Node.js installation is not configured for ${NEXUS_OS_FAMILY}."
				;;
		esac
	else
		log "Using installed Node.js $(node --version)."
	fi

	if ! command -v corepack >/dev/null 2>&1; then
		log "Installing Corepack..."
		npm install --global corepack
	fi

	corepack enable
	corepack prepare pnpm@9.0.6 --activate
}

build_ui() {
	log "Building the Nexus Cloud frontend..."
	cd "${NEXUS_INSTALL_ROOT}"
	pnpm --dir UI install --frozen-lockfile
	pnpm --dir UI build
}

main() {
	require_root "$@"

	if [[ ! -f "${LIB_DIR}/detect-os.sh" ]] || [[ ! -d "${NEXUS_INSTALL_ROOT}/.git" ]]; then
		bootstrap_checkout
	fi

	if [[ "${NEXUS_SKIP_UPDATE:-0}" != "1" ]]; then
		local previous_head
		previous_head="$(git -C "${NEXUS_INSTALL_ROOT}" rev-parse HEAD)"
		update_checkout
		if [[ "$(git -C "${NEXUS_INSTALL_ROOT}" rev-parse HEAD)" != "${previous_head}" ]]; then
			exec env NEXUS_SKIP_UPDATE=1 bash "${NEXUS_INSTALL_ROOT}/scripts/install-nexus.sh"
		fi
	fi

	# shellcheck source=scripts/lib/detect-os.sh
	source "${LIB_DIR}/detect-os.sh"
	# shellcheck source=scripts/lib/install-deps-debian.sh
	source "${LIB_DIR}/install-deps-debian.sh"
	# shellcheck source=scripts/lib/install-deps-rhel.sh
	source "${LIB_DIR}/install-deps-rhel.sh"
	# shellcheck source=scripts/lib/install-docker.sh
	source "${LIB_DIR}/install-docker.sh"
	# shellcheck source=scripts/lib/install-casaos.sh
	source "${LIB_DIR}/install-casaos.sh"
	# shellcheck source=scripts/lib/deploy-ui.sh
	source "${LIB_DIR}/deploy-ui.sh"
	# shellcheck source=scripts/lib/print-summary.sh
	source "${LIB_DIR}/print-summary.sh"

	detect_os
	detect_architecture
	install_dependencies
	install_docker_if_missing
	install_casaos_if_missing
	provision_node
	build_ui
	deploy_nexus_ui
	print_nexus_summary
}

main "$@"
