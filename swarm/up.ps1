$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

$prod = docker ps -q --filter "name=^prod$"
if ($prod) {
  Write-Host "Stopping single-node prod so ports 80 / 2222 / 8080 are free..."
  docker compose -f docker-compose.prod-host.yml down
}

Write-Host "Starting empty Linux hosts vm1, vm2, vm3..."
docker compose -f docker-compose.swarm.yml up -d --build

function Wait-Ssh([string]$Name) {
  Write-Host "Waiting for SSH on $Name..."
  for ($i = 0; $i -lt 60; $i++) {
    docker exec $Name systemctl is-active ssh 1>$null 2>$null
    if ($LASTEXITCODE -eq 0) {
      Write-Host "$Name is ready."
      return
    }
    Start-Sleep -Seconds 2
  }
  throw "SSH on $Name did not start in time."
}

Wait-Ssh vm1
Wait-Ssh vm2
Wait-Ssh vm3

Write-Host ""
Write-Host "Empty hosts are up. Nothing is installed yet."
Write-Host "  PuTTY  vm1  127.0.0.1 port 2222  lab / lab"
Write-Host "  PuTTY  vm2  127.0.0.1 port 2223  lab / lab"
Write-Host "  PuTTY  vm3  127.0.0.1 port 2224  lab / lab"
Write-Host ""
Write-Host "Follow swarm/README.md: Docker, Swarm, stack, nginx on vm1."
