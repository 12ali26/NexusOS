#!/usr/bin/env bash

set -Eeuo pipefail

readonly NEXUS_REPOSITORY_URL="${NEXUS_REPOSITORY_URL:-https://github.com/12ali26/NexusOS.git}"
readonly NEXUS_RELEASE_REPOSITORY="${NEXUS_RELEASE_REPOSITORY:-12ali26/NexusOS}"
readonly NEXUS_BRANCH="${NEXUS_BRANCH:-main}"
readonly NEXUS_INSTALL_ROOT="${NEXUS_INSTALL_ROOT:-/opt/nexusos}"
readonly NEXUS_STATE_ROOT="${NEXUS_STATE_ROOT:-/var/lib/nexus-cloud}"
readonly SCRIPT_SOURCE="${BASH_SOURCE[0]:-}"
readonly SCRIPT_DIR="$(cd "$(dirname "${SCRIPT_SOURCE:-.}")" 2>/dev/null && pwd || pwd)"
readonly LIB_DIR="${SCRIPT_DIR}/lib"

NEXUS_BUILD_FROM_SOURCE=0
NEXUS_VERSION=""
NEXUS_UI_SOURCE_ROOT=""
NEXUS_UI_CHECKSUM=""
NEXUS_WORK_ROOT=""

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

usage() {
	cat <<'EOF'
Usage: install-nexus.sh [options]

Options:
  --version TAG         Install a specific Nexus UI release, for example nexus-ui-v0.1.0.
  --build-from-source   Clone or update NexusOS and build the UI locally. For development only.
  --help                Show this help text.
EOF
}

parse_args() {
	while (( $# > 0 )); do
		case "$1" in
			--version)
				(( $# >= 2 )) || fail "--version requires a release tag."
				NEXUS_VERSION="$2"
				shift 2
				;;
			--build-from-source)
				NEXUS_BUILD_FROM_SOURCE=1
				shift
				;;
			--help|-h)
				usage
				exit 0
				;;
			*)
				fail "Unknown option: $1. Run with --help for usage."
				;;
		esac
	done
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

detect_os() {
	[[ -r /etc/os-release ]] || fail "Cannot detect Linux distribution: /etc/os-release is missing."
	# shellcheck source=/dev/null
	source /etc/os-release

	local distro_words=" ${ID:-} ${ID_LIKE:-} "
	if [[ "${distro_words}" == *" debian "* ]] || [[ "${distro_words}" == *" ubuntu "* ]] || [[ "${distro_words}" == *" raspbian "* ]]; then
		export NEXUS_OS_FAMILY="debian"
		export NEXUS_PACKAGE_MANAGER="apt-get"
	elif [[ "${distro_words}" == *" rhel "* ]] || [[ "${distro_words}" == *" fedora "* ]] || [[ "${distro_words}" == *" centos "* ]]; then
		export NEXUS_OS_FAMILY="rhel"
		export NEXUS_PACKAGE_MANAGER
		NEXUS_PACKAGE_MANAGER="$(command -v dnf || command -v yum || true)"
		[[ -n "${NEXUS_PACKAGE_MANAGER}" ]] || fail "Neither dnf nor yum is available."
		warn "CentOS/RHEL/Fedora support is experimental and has not been validated yet."
	else
		fail "Unsupported Linux distribution: ${ID:-unknown} (${ID_LIKE:-no ID_LIKE value})."
	fi

	log "Detected Linux distribution: ${ID:-unknown} ${VERSION_ID:-unknown} (${NEXUS_OS_FAMILY})."
}

detect_architecture() {
	local machine_arch
	machine_arch="$(uname -m)"

	case "${machine_arch}" in
		x86_64|amd64) export NEXUS_ARCH="amd64" ;;
		aarch64|arm64) export NEXUS_ARCH="arm64" ;;
		armv7l|armv7*) export NEXUS_ARCH="armv7" ;;
		*)
			export NEXUS_ARCH="${machine_arch}"
			warn "Architecture ${machine_arch} is not one of the expected amd64, arm64, or armv7 targets. Continuing experimentally."
			;;
	esac

	log "Detected CPU architecture: ${NEXUS_ARCH}."
}

install_dependencies() {
	log "Installing required packages..."
	case "${NEXUS_OS_FAMILY}" in
		debian)
			apt-get update
			DEBIAN_FRONTEND=noninteractive apt-get install -y curl ca-certificates rsync tar
			;;
		rhel)
			warn "Installing dependencies through the experimental CentOS/RHEL/Fedora path."
			"${NEXUS_PACKAGE_MANAGER}" install -y curl ca-certificates rsync tar
			;;
	esac
}

install_docker_if_missing() {
	if command -v docker >/dev/null 2>&1; then
		log "Docker is already installed."
	else
		log "Installing Docker with Docker's convenience script..."
		curl -fsSL https://get.docker.com | sh
	fi

	if command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]; then
		systemctl enable --now docker
	else
		warn "systemd is unavailable. Confirm that the Docker daemon is running before installing apps."
	fi
}

install_casaos_if_missing() {
	if command -v casaos >/dev/null 2>&1; then
		log "CasaOS is already installed."
		return
	fi

	log "Installing CasaOS with the official installer..."
	curl -fsSL https://get.casaos.io | bash
}

download_release_ui() {
	local release_base
	local release_json
	NEXUS_WORK_ROOT="$(mktemp -d)"
	trap 'rm -rf "${NEXUS_WORK_ROOT:-}"' EXIT

	if [[ -n "${NEXUS_VERSION}" ]]; then
		release_base="https://github.com/${NEXUS_RELEASE_REPOSITORY}/releases/download/${NEXUS_VERSION}"
	else
		log "Resolving the latest stable Nexus Cloud UI release..."
		release_json="$(
			curl --retry 3 --retry-delay 2 -fsSL \
				"https://api.github.com/repos/${NEXUS_RELEASE_REPOSITORY}/releases/latest"
		)" || fail "No stable Nexus Cloud UI release is available yet."
		NEXUS_VERSION="$(
			printf '%s\n' "${release_json}" |
				sed -nE 's/.*"tag_name":[[:space:]]*"([^"]+)".*/\1/p' |
				head -n 1
		)"
		[[ -n "${NEXUS_VERSION}" ]] || fail "No stable Nexus Cloud UI release is available yet."
		release_base="https://github.com/${NEXUS_RELEASE_REPOSITORY}/releases/latest/download"
	fi

	log "Downloading Nexus Cloud UI release${NEXUS_VERSION:+ ${NEXUS_VERSION}}..."
	curl --retry 3 --retry-delay 2 -fL "${release_base}/nexus-ui.tar.gz" \
		-o "${NEXUS_WORK_ROOT}/nexus-ui.tar.gz" ||
		fail "Unable to download nexus-ui.tar.gz for release ${NEXUS_VERSION}."
	curl --retry 3 --retry-delay 2 -fL "${release_base}/nexus-ui.tar.gz.sha256" \
		-o "${NEXUS_WORK_ROOT}/nexus-ui.tar.gz.sha256" ||
		fail "Unable to download nexus-ui.tar.gz.sha256 for release ${NEXUS_VERSION}."

	(
		cd "${NEXUS_WORK_ROOT}"
		sha256sum --check nexus-ui.tar.gz.sha256
	)

	NEXUS_UI_CHECKSUM="$(sha256sum "${NEXUS_WORK_ROOT}/nexus-ui.tar.gz" | awk '{ print $1 }')"
	mkdir -p "${NEXUS_WORK_ROOT}/staging"
	tar -xzf "${NEXUS_WORK_ROOT}/nexus-ui.tar.gz" -C "${NEXUS_WORK_ROOT}/staging"
	[[ -f "${NEXUS_WORK_ROOT}/staging/www/index.html" ]] || fail "Release archive is invalid: www/index.html is missing."
	NEXUS_UI_SOURCE_ROOT="${NEXUS_WORK_ROOT}/staging/www"
}

install_development_dependencies() {
	case "${NEXUS_OS_FAMILY}" in
		debian)
			DEBIAN_FRONTEND=noninteractive apt-get install -y git
			;;
		rhel)
			"${NEXUS_PACKAGE_MANAGER}" install -y git
			;;
	esac
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

	log "Updating ${NEXUS_INSTALL_ROOT} with fast-forward-only Git semantics..."
	git -C "${NEXUS_INSTALL_ROOT}" fetch origin "${NEXUS_BRANCH}"
	git -C "${NEXUS_INSTALL_ROOT}" merge --ff-only "origin/${NEXUS_BRANCH}"
}

provision_node() {
	local node_major=0
	if command -v node >/dev/null 2>&1; then
		node_major="$(node --version | sed -E 's/^v([0-9]+).*/\1/')"
	fi

	if (( node_major < 22 )); then
		log "Installing Node.js 22 LTS for the developer source build..."
		case "${NEXUS_OS_FAMILY}" in
			debian)
				curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
				DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs
				;;
			rhel)
				curl -fsSL https://rpm.nodesource.com/setup_22.x | bash -
				"${NEXUS_PACKAGE_MANAGER}" install -y nodejs
				;;
		esac
	fi

	if ! command -v corepack >/dev/null 2>&1; then
		npm install --global corepack
	fi
	corepack enable
	corepack prepare pnpm@9.0.6 --activate
}

build_source_ui() {
	warn "Using developer source-build mode. This installs build tools and is not the normal production path."
	install_development_dependencies
	update_checkout
	provision_node
	log "Building the Nexus Cloud frontend from source..."
	(
		cd "${NEXUS_INSTALL_ROOT}"
		pnpm --dir UI install --frozen-lockfile
		pnpm --dir UI build
	)
	NEXUS_VERSION="source-$(git -C "${NEXUS_INSTALL_ROOT}" rev-parse --short HEAD)"
	NEXUS_UI_SOURCE_ROOT="${NEXUS_INSTALL_ROOT}/UI/build/sysroot/var/lib/casaos/www"
	NEXUS_UI_CHECKSUM="source-build"
}

deploy_nexus_ui() {
	local web_root="${NEXUS_WEB_ROOT:-/var/lib/casaos/www}"
	local state_root="${NEXUS_STATE_ROOT}"
	local timestamp
	timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
	export NEXUS_UI_BACKUP="${web_root}.backup-${timestamp}"

	[[ -f "${NEXUS_UI_SOURCE_ROOT}/index.html" ]] || fail "Frontend source is invalid: index.html is missing."

	if [[ -d "${web_root}" ]]; then
		log "Backing up the current CasaOS UI to ${NEXUS_UI_BACKUP}..."
		cp -a "${web_root}" "${NEXUS_UI_BACKUP}"
	else
		warn "${web_root} does not exist. No existing CasaOS UI was available to back up."
		NEXUS_UI_BACKUP="none"
	fi

	log "Deploying the Nexus Cloud UI..."
	mkdir -p "${web_root}" "${state_root}"
	rsync -a --delete "${NEXUS_UI_SOURCE_ROOT}/" "${web_root}/"
	[[ -f "${web_root}/index.html" ]] || fail "Deployed Nexus Cloud UI is invalid: ${web_root}/index.html is missing."

	if [[ "${NEXUS_SKIP_PERMISSIONS:-0}" == "1" ]]; then
		warn "Skipping UI ownership and mode normalization because NEXUS_SKIP_PERMISSIONS=1."
	else
		log "Normalizing Nexus Cloud UI ownership and modes..."
		chown -R root:root "${web_root}"
		find "${web_root}" -type d -exec chmod 755 {} +
		find "${web_root}" -type f -exec chmod 644 {} +
	fi

	printf '%s\n' "${NEXUS_VERSION:-latest}" > "${state_root}/ui-release"
	printf '%s\n' "${NEXUS_UI_CHECKSUM}" > "${state_root}/ui-sha256"

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

get_casaos_port() {
	local gateway_config="/etc/casaos/gateway.ini"
	local port=""
	if [[ -r "${gateway_config}" ]]; then
		port="$(sed -nE 's/^[[:space:]]*(HttpPort|port)[[:space:]]*=[[:space:]]*"?([0-9]+)"?.*/\2/p' "${gateway_config}" | head -n 1)"
	fi
	printf '%s\n' "${port:-80}"
}

print_nexus_summary() {
	local port
	port="$(get_casaos_port)"
	printf '\nNexus Cloud UI deployed successfully.\n'
	printf 'UI release: %s\n' "${NEXUS_VERSION:-latest}"
	printf 'Backup: %s\n\n' "${NEXUS_UI_BACKUP:-none}"
	printf 'Possible local access URLs:\nhttp://localhost%s\n' "$([[ "${port}" == "80" ]] || printf ':%s' "${port}")"

	local ip
	for ip in $(hostname -I 2>/dev/null || true); do
		if [[ "${ip}" == *.* ]] && [[ "${ip}" != "127."* ]]; then
			printf 'http://%s%s\n' "${ip}" "$([[ "${port}" == "80" ]] || printf ':%s' "${port}")"
		fi
	done

	printf '\nOpen port %s in your firewall or VPS security group if remote access is required.\n' "${port}"
	printf 'Installed apps may use additional ports. Open only the ports you intentionally need.\n'
	printf 'This experimental installer does not configure HTTPS, authentication, or a reverse proxy.\n'
}

main() {
	parse_args "$@"
	require_root "$@"
	detect_os
	detect_architecture
	install_dependencies
	install_docker_if_missing
	install_casaos_if_missing

	if (( NEXUS_BUILD_FROM_SOURCE == 1 )); then
		build_source_ui
	else
		download_release_ui
	fi

	deploy_nexus_ui
	print_nexus_summary
}

main "$@"
