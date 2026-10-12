$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

Write-Host "Stopping Linux hosts vm1, vm2, and vm3..."
docker compose -f docker-compose.swarm.yml down
Write-Host "Add -v to also wipe Docker data you installed on the hosts: docker compose -f docker-compose.swarm.yml down -v"
