#!/usr/bin/env bash

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

	export NEXUS_DISTRO_ID="${ID:-unknown}"
	export NEXUS_DISTRO_VERSION="${VERSION_ID:-unknown}"
	log "Detected Linux distribution: ${NEXUS_DISTRO_ID} ${NEXUS_DISTRO_VERSION} (${NEXUS_OS_FAMILY})."
}

detect_architecture() {
	local machine_arch
	machine_arch="$(uname -m)"

	case "${machine_arch}" in
		x86_64|amd64)
			export NEXUS_ARCH="amd64"
			;;
		aarch64|arm64)
			export NEXUS_ARCH="arm64"
			;;
		armv7l|armv7*)
			export NEXUS_ARCH="armv7"
			;;
		*)
			export NEXUS_ARCH="${machine_arch}"
			warn "Architecture ${machine_arch} is not one of the expected amd64, arm64, or armv7 targets. Continuing experimentally."
			;;
	esac

	log "Detected CPU architecture: ${NEXUS_ARCH}."
}
