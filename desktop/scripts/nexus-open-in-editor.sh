#!/usr/bin/env bash

set -Eeuo pipefail

readonly CONFIG_ROOT="${NEXUS_DESKTOP_CONFIG_ROOT:-/config}"
readonly FLAGS_CONFIG="${CONFIG_ROOT}/nexus/electron-flags.conf"
readonly EDITOR_CONFIG="${CONFIG_ROOT}/nexus/editor-command.conf"
readonly -a DEFAULT_ELECTRON_FLAGS=(
	--xdg-portal-required-version=999
	--no-sandbox
	--disable-gpu
)

log() {
	printf '[Nexus Open Editor] %s\n' "$*"
}

fail() {
	printf '[Nexus Open Editor] ERROR: %s\n' "$*" >&2
	exit 1
}

resolve_command() {
	local command_name="$1"

	if [[ "${command_name}" == /* ]]; then
		[[ -x "${command_name}" ]] && printf '%s\n' "${command_name}"
	else
		command -v "${command_name}" 2>/dev/null || true
	fi
}

choose_editor() {
	local configured_editor
	local candidate
	local -a candidates=(
		codium
		code
		cursor
		/usr/share/codium/codium
		/usr/share/code/code
		/usr/share/cursor/cursor
		/usr/share/Cursor/cursor
		/opt/cursor/cursor
		/opt/Cursor/cursor
	)

	if [[ -n "${NEXUS_DESKTOP_EDITOR:-}" ]]; then
		configured_editor="$(resolve_command "${NEXUS_DESKTOP_EDITOR}")"
		[[ -n "${configured_editor}" ]] && {
			printf '%s\n' "${configured_editor}"
			return 0
		}
	fi

	if [[ -f "${EDITOR_CONFIG}" ]]; then
		configured_editor="$(grep -Ev '^[[:space:]]*(#|$)' "${EDITOR_CONFIG}" | head -n 1 || true)"
		if [[ -n "${configured_editor}" ]]; then
			configured_editor="$(resolve_command "${configured_editor}")"
			[[ -n "${configured_editor}" ]] && {
				printf '%s\n' "${configured_editor}"
				return 0
			}
		fi
	fi

	for candidate in "${candidates[@]}"; do
		candidate="$(resolve_command "${candidate}")"
		[[ -n "${candidate}" ]] || continue
		printf '%s\n' "${candidate}"
		return 0
	done

	return 1
}

needs_electron_flags() {
	local editor="$1"
	local editor_name="${editor##*/}"
	local editor_dir

	case "${editor_name}" in
		codium | code | cursor | electron)
			return 0
			;;
	esac

	editor_dir="$(dirname "${editor}")"
	[[ -d "${editor_dir}/resources/app" ]] ||
		[[ -f "${editor_dir}/resources/app.asar" ]] ||
		[[ -f "${editor_dir}/resources/default_app.asar" ]]
}

read_electron_flags() {
	local flag
	local -A seen_flags=()

	for flag in "${DEFAULT_ELECTRON_FLAGS[@]}"; do
		[[ -z "${seen_flags[${flag}]:-}" ]] || continue
		seen_flags["${flag}"]=1
		printf '%s\n' "${flag}"
	done

	[[ -f "${FLAGS_CONFIG}" ]] || return 0
	while IFS= read -r flag; do
		[[ -z "${seen_flags[${flag}]:-}" ]] || continue
		seen_flags["${flag}"]=1
		printf '%s\n' "${flag}"
	done < <(grep -Ev '^[[:space:]]*(#|$)' "${FLAGS_CONFIG}" || true)
}

main() {
	local editor
	local -a targets=("$@")
	local -a flags=()

	editor="$(choose_editor)" || fail "No supported editor is installed. Install VSCodium, VS Code, Cursor, or set ${EDITOR_CONFIG}."
	if ((${#targets[@]} == 0)); then
		targets=("${CONFIG_ROOT}/Workspace")
	fi

	if needs_electron_flags "${editor}"; then
		mapfile -t flags < <(read_electron_flags)
	fi

	log "Opening ${targets[*]} with ${editor}"
	"${editor}" "${flags[@]}" "${targets[@]}" >/dev/null 2>&1 &
}

main "$@"
