#!/usr/bin/env bash

get_casaos_port() {
	local gateway_config="/etc/casaos/gateway.ini"
	local port=""

	if [[ -r "${gateway_config}" ]]; then
		port="$(sed -nE 's/^[[:space:]]*(HttpPort|port)[[:space:]]*=[[:space:]]*"?([0-9]+)"?.*/\2/p' "${gateway_config}" | head -n 1)"
	fi

	printf '%s\n' "${port:-80}"
}

format_nexus_url() {
	local host="$1"
	local port="$2"
	if [[ "${port}" == "80" ]]; then
		printf 'http://%s\n' "${host}"
	else
		printf 'http://%s:%s\n' "${host}" "${port}"
	fi
}

print_nexus_summary() {
	local port
	port="$(get_casaos_port)"

	printf '\n'
	printf 'Nexus Cloud UI deployed successfully.\n'
	printf 'Backup: %s\n' "${NEXUS_UI_BACKUP:-none}"
	printf '\nPossible local access URLs:\n'
	format_nexus_url "localhost" "${port}"

	local ip
	for ip in $(hostname -I 2>/dev/null || true); do
		if [[ "${ip}" == *.* ]] && [[ "${ip}" != "127."* ]]; then
			format_nexus_url "${ip}" "${port}"
		fi
	done

	printf '\n'
	printf 'Open port %s in your firewall or VPS security group if remote access is required.\n' "${port}"
	printf 'Installed apps may use additional ports. Open only the ports you intentionally need.\n'
	printf 'This experimental installer does not configure HTTPS, authentication, or a reverse proxy.\n'
}
