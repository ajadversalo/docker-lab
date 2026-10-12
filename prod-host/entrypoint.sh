#!/bin/bash
set -euo pipefail

ssh-keygen -A

HOST="$(hostname)"
cat >/etc/motd <<EOF

============================================================
  Empty Linux host  (hostname: ${HOST})
  PuTTY/SSH the same way you would at work.

  Login:  lab / lab   (local training only)

  Nothing extra is installed yet. Next:
    1. Install Docker
    2. Swarm on vm2 + vm3, nginx on vm1
    3. Deploy the app (git clone or copy from Windows)

  Guide: swarm/README.md in the docker-lab repo
============================================================
EOF

exec /lib/systemd/systemd
