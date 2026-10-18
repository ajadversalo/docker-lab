# Three Linux hosts, nginx, and Swarm

Do this yourself on the boxes. The Windows scripts only start and stop empty hosts. Swarm join happens **once**. After that you deploy and update.

```text
[ Incoming traffic  http://localhost ]
                    │
                    v
               vm1  nginx     ← you install this (apt)
               /          \
              v            v
            vm2          vm3
         manager         worker
         1 web + 1 api   1 web + 1 api
              \          /
        Docker routing mesh
        overlay: web → api:8080
```

No database and no Redis. The API serves a hardcoded list. The page badge shows which replica answered.

---

## Ports

| Host | SSH (PuTTY) | Windows → host :80 | Windows → host :8080 |
| --- | --- | --- | --- |
| vm1 | 2222 | http://localhost | http://localhost:8080 |
| vm2 | 2223 | http://localhost:82 | http://localhost:8082 |
| vm3 | 2224 | http://localhost:81 | http://localhost:8081 |

`localhost` is **always vm1**. Direct ports on 81/82 are for debugging a node.

`docker stop vm2` is like powering a VM off. `docker compose down` is like deleting the VMs. Named volumes keep `/var/lib/docker` unless you add `-v`.

---

## 0. Start the boxes (Windows)

Docker Desktop must be running.

```powershell
cd C:\repos\docker-lab
.\swarm\up.ps1
```

Docker Desktop shows project `docker-lab-swarm` with `vm1`, `vm2`, `vm3`.

---

## 1. PuTTY into each host

User `lab`, password `lab`.

| Host | PuTTY |
| --- | --- |
| vm1 | `127.0.0.1` port **2222** |
| vm2 | `127.0.0.1` port **2223** |
| vm3 | `127.0.0.1` port **2224** |

Or from PowerShell:

```powershell
ssh -p 2222 lab@127.0.0.1
ssh -p 2223 lab@127.0.0.1
ssh -p 2224 lab@127.0.0.1
```

On the box, `hostname` prints `vm1`, `vm2`, or `vm3`. `docker` is not installed yet.

---

## 2. Install Docker (all three hosts)

On **vm1**, **vm2**, and **vm3**:

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker lab
sudo systemctl enable --now docker
```

Log out of SSH and log back in so the `docker` group applies. Then:

```bash
docker version
sudo systemctl status docker
```

vm1 uses Docker only so the engine is there if you want it. Incoming traffic uses **apt nginx**, not a Docker nginx container.

---

## 3. Put the code on the app nodes

Real hosts clone from GitHub. This folder is not a git remote yet, so pick one path.

### Path A — GitHub (real life)

On Windows, create a GitHub repo, push `C:\repos\docker-lab`, then on **vm2** and **vm3**:

```bash
git clone https://github.com/<your-account>/docker-lab.git
cd docker-lab
```

### Path B — copy from Windows (lab, no GitHub yet)

From **PowerShell on Windows**:

```powershell
docker cp C:\repos\docker-lab vm2:/home/lab/docker-lab
docker cp C:\repos\docker-lab vm3:/home/lab/docker-lab
docker exec vm2 sudo chown -R lab:lab /home/lab/docker-lab
docker exec vm3 sudo chown -R lab:lab /home/lab/docker-lab
```

On the box you should see `/home/lab/docker-lab/Api1`, `Web1`, and `swarm/stack.yml`.

---

## 4. Build the images (vm2 and vm3)

Swarm runs the image that **already exists on that node**. Build on **both** app nodes so each has `docker-lab-api:latest` and `docker-lab-web:latest`.

On **vm2**:

```bash
cd ~/docker-lab
docker build -t docker-lab-api:latest ./Api1
docker build -t docker-lab-web:latest ./Web1
docker images
```

Repeat the same three commands on **vm3**.

---

## 5. Swarm init and join (once)

On **vm2** (manager):

```bash
docker swarm init --advertise-addr eth0
```

Copy the `docker swarm join --token ...` line it prints.

On **vm3** (worker), paste that join command. It looks like:

```bash
docker swarm join --token SWMTKN-1-... vm2:2377
```

On **vm2** check the cluster:

```bash
docker node ls
```

You should see `vm2` Leader and `vm3` Ready. **Do not join vm1.** vm1 stays outside the Swarm and only runs nginx.

If you need to join again later:

```bash
# on the worker
docker swarm leave --force
# on the manager
docker swarm join-token worker
```

---

## 6. Deploy the stack (vm2)

Still on **vm2**:

```bash
cd ~/docker-lab
docker stack deploy -c swarm/stack.yml lab --resolve-image never
```

`--resolve-image never` means “use the images we just built; do not pull from Docker Hub.”

Watch until both services show 2/2:

```bash
docker stack services lab
docker service ps lab_web
docker service ps lab_api
```

`max_replicas_per_node: 1` puts one web and one api task on vm2, and one of each on vm3.

How the mesh works:

- Publish port 80 (web) and 8080 (api) on the Swarm. Hit **either** vm2 or vm3 on those ports. Docker picks a replica.
- Web containers call `http://api:8080` on the overlay network. That name is a Swarm VIP, not nginx.

From Windows you can already poke a node directly:

```powershell
curl http://localhost:82/health
curl http://localhost:81/health
```

Those hit vm2:80 and vm3:80 (the published web port). Refresh the page later through nginx to see the replica badge flip.

---

## 7. nginx on vm1

nginx is the public door. It load-balances to vm2 and vm3. `localhost` stays up if one app node is off.

vm1 `/tmp` is tmpfs. `docker cp` into `/tmp` never shows up inside the VM. Copy to `/home/lab` instead.

From **PowerShell**:

```powershell
docker cp C:\repos\docker-lab\swarm\nginx.conf vm1:/home/lab/nginx.conf
```

On **vm1** (nginx is not in the image; `/etc/nginx` appears after apt):

```bash
sudo apt-get update
sudo apt-get install -y nginx
sudo cp /home/lab/nginx.conf /etc/nginx/nginx.conf
sudo nginx -t
sudo systemctl enable --now nginx
```

`apt` may print `policy-rc.d denied execution of start`. That only skips auto-start during install. `enable --now` starts the service.

`swarm/nginx.conf` is two upstreams and two listeners:

- port 80 → `vm2:80` and `vm3:80` (web, `least_conn`)
- port 8080 → `vm2:8080` and `vm3:8080` (api)

From vm1 you can `ping vm2` and `ping vm3`. Docker DNS knows those names.

API paths are `/health` and `/api/items` (there is no `/weatherforecast`).

---

## 8. Verify from Windows

```powershell
curl http://localhost/health
curl http://localhost:8080/health
curl http://localhost:8080/api/items
```

Open http://localhost in a browser. You should see the Web1 page and a replica badge like `web-1@vm2 → api-1@vm3`. Refresh a few times. The names can change because nginx and the routing mesh both pick a backend.

| URL | What answers |
| --- | --- |
| http://localhost | nginx on vm1 → a web replica |
| http://localhost:8080/health | nginx on vm1 → an api replica |
| http://localhost:82 | vm2 directly (mesh) |
| http://localhost:81 | vm3 directly (mesh) |

---

## 9. Failover (vm2 off, localhost still works)

From **Windows**:

```powershell
docker stop vm2
curl http://localhost/health
```

nginx marks vm2 failed and sends traffic to vm3. The page at http://localhost should still load. The badge should show vm3.

Bring vm2 back:

```powershell
docker start vm2
```

Wait a few seconds for SSH and Docker on vm2. The manager returns, Swarm still has the stack, and nginx uses both nodes again.

---

## 10. Update Web1: GitHub code, manual GHCR, pull on the nodes

Code lives on GitHub. You build on Windows and `docker push` to GHCR. Then you SSH to each app node, **pull**, and on the manager tell Swarm to run the new tag. No GitHub Actions.

Image: `ghcr.io/ajadversalo/docker-lab/web:v2`

### Already done (this pass)

1. Edit `Web1/app/page.tsx` (heading shows `(v2)`).
2. `git push` to GitHub.
3. On Windows: `docker build` and `docker push` `ghcr.io/ajadversalo/docker-lab/web:v2`.

Windows GHCR login does not apply inside the VMs.

### Pull on vm2, then on vm3

SSH **vm2** (`127.0.0.1` port `2223`). If pull returns `denied`, log in on that VM first:

```bash
echo 'YOUR_PAT' | docker login ghcr.io -u ajadversalo --password-stdin
```

Then:

```bash
docker pull ghcr.io/ajadversalo/docker-lab/web:v2
docker images | grep docker-lab/web
```

SSH **vm3** (`127.0.0.1` port `2224`). Same login if needed, then the same `docker pull` and `docker images` check.

Both nodes need the image because one web task runs on each.

### Update the service (vm2 only)

Still on **vm2** (manager):

```bash
docker service update --image ghcr.io/ajadversalo/docker-lab/web:v2 lab_web
docker service ps lab_web
```

Wait until both tasks are `Running`, one on vm2 and one on vm3. Hard-refresh http://localhost:82 and http://localhost:81. Both should show **(v2)**.

---

## Stop the boxes (Windows)

```powershell
.\swarm\down.ps1
```

That removes `vm1`/`vm2`/`vm3`. Docker packages and Swarm state live in named volumes, so the next `.\swarm\up.ps1` can come back with Docker already installed.

Wipe engine data (images, Swarm, everything on the boxes):

```powershell
docker compose -f docker-compose.swarm.yml down -v
```

---

## Everyday commands on the manager (vm2)

```bash
docker node ls
docker stack services lab
docker service ps lab_web
docker service logs -f lab_web
docker stack rm lab
```

On any app node:

```bash
docker ps
docker images
sudo systemctl status docker
```

---

## If something fails

| Symptom | What to check |
| --- | --- |
| `docker` not found | Step 2, then log out and back in |
| `permission denied` talking to Docker | `groups` should include `docker`; re-login |
| stack 0/2 or 1/2 | Images missing on a node — rebuild on **both** vm2 and vm3 |
| `no such image` | Deploy used `--resolve-image never` and that node has no tag `docker-lab-api:latest` / `docker-lab-web:latest` |
| localhost 502 / 504 | Stack not up, or nginx not installed, or both app nodes down |
| `docker cp` to `/tmp` missing on vm1 | `/tmp` is tmpfs; copy to `/home/lab/nginx.conf` |
| `/etc/nginx` does not exist | nginx is not installed yet — `apt-get install -y nginx` |
| `swarm init` already part of a swarm | `docker swarm leave --force` then init/join again |
| Port 80 already allocated on Windows | Stop local `docker compose` or the single `prod` host |

Related lesson: [Simulated production host](../prod-host/README.md) is one Linux box, not this three-node Swarm.
