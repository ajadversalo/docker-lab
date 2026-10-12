# Docker lab

A **VM** here is a separate Linux host you SSH into. It is not Hyper-V. Docker Desktop on Windows only starts the boxes.

The lab you use going forward is **three empty Linux hosts**. You PuTTY in, install Docker, join a Swarm, deploy the app, and put nginx on vm1.

```text
[ Incoming traffic  http://localhost ]
                    │
                    v
               vm1  nginx
               /          \
              v            v
            vm2          vm3
         Swarm manager   worker
         web + api       web + api
              \          /
               routing mesh
```

Full walkthrough: **[swarm/README.md](swarm/README.md)**

```powershell
.\swarm\up.ps1
```

| Host | Role | PuTTY | User |
| --- | --- | --- | --- |
| vm1 | nginx (incoming) | `127.0.0.1` port **2222** | `lab` / `lab` |
| vm2 | Swarm manager, app node | `127.0.0.1` port **2223** | `lab` / `lab` |
| vm3 | Swarm worker, app node | `127.0.0.1` port **2224** | `lab` / `lab` |

http://localhost always hits **vm1**. If vm2 is off, nginx still reaches vm3.

Do not run the other modes below at the same time as these three hosts. They share ports 80, 2222, and 8080.

---

## Other modes (optional)

- **One Linux host (`prod`)** — same empty Ubuntu image, bind-mounted repo. [prod-host/README.md](prod-host/README.md)
- **Local Compose on Windows** — five containers, no SSH. `docker compose up --build` in this folder.

---

## What lives in this folder

| Path | What it is |
| --- | --- |
| `docker-compose.swarm.yml` | Starts empty hosts `vm1` / `vm2` / `vm3` |
| `prod-host/` | Ubuntu image: SSH + systemd. **No Docker in the image.** |
| `swarm/` | Lesson, stack file, nginx config, start/stop scripts |
| `Api1/` | Static JSON API (no database) |
| `Web1/` | Next.js page that reads the API |
| `nginx/` | nginx image for **local Compose only** |
| `docker-compose.yml` | Local Compose on Windows |

Web2 is the same `Web1` image with different env vars. There is no `Web2/` folder.
