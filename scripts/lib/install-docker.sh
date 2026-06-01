#!/usr/bin/env bash

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
