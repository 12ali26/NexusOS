#!/usr/bin/env bash

install_casaos_if_missing() {
	if command -v casaos >/dev/null 2>&1; then
		log "CasaOS is already installed."
		return
	fi

	log "Installing CasaOS with the official installer..."
	curl -fsSL https://get.casaos.io | bash
}
