#!/usr/bin/env bash

install_dependencies_debian() {
	log "Installing required packages with apt..."
	apt-get update
	DEBIAN_FRONTEND=noninteractive apt-get install -y curl ca-certificates rsync tar
}

install_dependencies() {
	case "${NEXUS_OS_FAMILY}" in
		debian)
			install_dependencies_debian
			;;
		rhel)
			install_dependencies_rhel
			;;
		*)
			fail "Dependency installation is not configured for ${NEXUS_OS_FAMILY}."
			;;
	esac
}
