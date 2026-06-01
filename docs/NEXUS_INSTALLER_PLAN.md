# Nexus Installer Plan

## Future Command

```sh
curl -fsSL https://get.nexuscloud.example/install.sh | bash
```

The hostname above is a placeholder until an official distribution endpoint is
selected.

## Installer Goals

1. Detect the supported operating system and install Docker when missing.
2. Install the Nexus Cloud CasaOS fork without renaming CasaOS-compatible
   services or data paths.
3. Register the curated Nexus App Store source.
4. Apply conservative defaults suitable for a browser-accessible personal
   computer.
5. Print the dashboard and recommended application access URLs.
6. Warn clearly about open ports, public exposure, HTTPS, and authentication.

## Guardrails

The installer should be repeatable, fail with actionable messages, and avoid
silently exposing application ports. Reverse-proxy automation and profile-based
app installation belong in a later milestone.
