# Nexus Desktop Developer Edition

## Milestone 7B

Nexus Desktop Developer Edition is the opt-in repository-checkout workstation
image:

```text
nexus-desktop-developer:7b
```

It keeps the persistent `/DATA/Nexus` folder model and Milestone 6B theme while
baking common development tools into a reproducible image.

## Included Tools

- Git, curl, wget, CA certificates, GnuPG, and common desktop utilities.
- Python 3, pip, and virtual environments.
- Ubuntu Node.js 22 LTS with Corepack.
- Build tools, unzip, jq, nano, and htop.
- VSCodium as the baked editor.
- Arc-Dark, Papirus-Dark, Inter fonts, and the Nexus XFCE profile.

The separate Ubuntu `npm` package is intentionally omitted to keep the image
lean. Corepack is available for package-manager activation.

VSCodium is the distributable default. Official VS Code remains installable
through the Milestone 7A `.deb` helper for users who choose Microsoft's
licensed distribution. Cursor remains user-installed only. Ollama and AI
runtime bundling are deferred.

## Build and Deploy

```sh
cd ~/NexusOS
git pull
cd desktop
docker compose -f docker-compose.yml -f docker-compose.premium.yml build --pull nexus-desktop
docker compose -f docker-compose.yml -f docker-compose.premium.yml up -d --force-recreate
```

Open the persistent workspace:

```sh
codium /config/Workspace
```

The container path maps to:

```text
/config/Workspace -> /DATA/Nexus/Workspace
```

## Verify

```sh
docker exec nexus-desktop git --version
docker exec nexus-desktop python3 --version
docker exec nexus-desktop node --version
docker exec nexus-desktop corepack --version
docker exec -u abc nexus-desktop codium --version
```

Use `-u abc` for VSCodium verification because Electron refuses root
execution.

## Persistence Model

Files under `/DATA/Nexus` survive restarts and container recreation. Tools
baked into `Dockerfile.premium` survive rebuilds. Applications installed
manually inside a running container may disappear when the container is
recreated.

To add another maintained apt-based application later, extend
`Dockerfile.premium`, rebuild the Developer Edition image, and recreate the
desktop service.

## Known Limits

- Developer Edition remains opt-in until root installer integration is added.
- Official VS Code and Cursor are not baked into the image.
- Ollama, Docker-in-Docker, heavy shell frameworks, and default editor
  extensions are deferred.
- Direct access remains `https://SERVER_IP:6901` with prototype HTTPS
  limitations.
