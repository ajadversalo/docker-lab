# Empty Linux host image

Ubuntu 24.04 with SSH and systemd. **Docker is not installed.** You log in and install it.

The three-host Swarm lab is the main path: [../swarm/README.md](../swarm/README.md).

## What this image contains

SSH, git, curl, sudo, systemd as PID 1. Login `lab` / `lab` (local training only).

## Optional: one box (`prod`)

Same image, repo bind-mounted at `/opt/docker-lab`. Do not run this at the same time as `vm1`/`vm2`/`vm3` (ports 80, 2222, 8080).

```powershell
docker compose -f docker-compose.prod-host.yml up -d --build
```

PuTTY: `127.0.0.1` port `2222`, user `lab`, password `lab`.

On the box, install Docker the same way as the swarm guide, then create containers yourself.
