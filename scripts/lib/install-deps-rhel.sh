#!/usr/bin/env bash

install_dependencies_rhel() {
	warn "Installing dependencies through the experimental CentOS/RHEL/Fedora path."
	"${NEXUS_PACKAGE_MANAGER}" install -y curl git ca-certificates rsync
}
