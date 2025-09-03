Param(
  [switch]$ForceRemoveContainers,  # also remove containers using these images
  [switch]$PruneDangling,          # prune dangling layers after removals
  [switch]$IncludeK8s,             # include Docker Desktop Kubernetes images
  [switch]$DryRun                  # show what would happen, don’t change anything
)

$allImages = @(
  "maestro-frontend:latest",
  "maestro-nginx:latest",
  "welcome-to-docker:latest",
  "ghcr.io/github/github-mcp-server:latest",
  "pgvector/pgvector:pg15",
  "mongo:6",
  "redis:alpine",
  "redis:7-alpine",
  "postgres:latest",
  "drewsk/docker-sql-extension:0.3.0",

  # Docker Desktop Kubernetes images (often re-pulled automatically)
  "docker/desktop-kubernetes:kubernetes-v1.32.2-cni-v1.6.0-critools-v1.31.1-cri-dockerd-v0.3.16-1-debian",
  "registry.k8s.io/kube-apiserver:v1.32.2",
  "registry.k8s.io/kube-controller-manager:v1.32.2",
  "registry.k8s.io/kube-scheduler:v1.32.2",
  "registry.k8s.io/kube-proxy:v1.32.2",
  "registry.k8s.io/etcd:3.5.16-0",
  "registry.k8s.io/coredns/coredns:v1.11.3",
  "registry.k8s.io/pause:3.10",

  # Docker Desktop extension/system images
  "grafana/docker-desktop-extension:2.0.0",
  "docker/desktop-vpnkit-controller:dc331cb22850be0cdd97c84a9cfecaf44a1afb6e",
  "docker/desktop-storage-provisioner:v2.0",

  # Others
  "langchain/langchain:latest",
  "docker/welcome-to-docker:latest",
  "virag/redis-enterprise-docker-extension:0.1.0"
)

# Optionally exclude Kubernetes images unless explicitly included
if (-not $IncludeK8s) {
  $images = $allImages | Where-Object { ($_ -notmatch '^docker/desktop-kubernetes:') -and ($_ -notmatch '^registry\.k8s\.io/') }
} else {
  $images = $allImages
}

$removed  = New-Object System.Collections.Generic.List[string]
$skipped  = New-Object System.Collections.Generic.List[string]
$notFound = New-Object System.Collections.Generic.List[string]
$errors   = New-Object System.Collections.Generic.List[string]

function Get-ImageId([string]$ref) {
  $line = docker images --format "{{.Repository}}:{{.Tag}} {{.ID}}" | Where-Object { $_.StartsWith("$ref ") } | Select-Object -First 1
  if ($line) { return ($line -split ' ')[1] } else { return $null }
}

function Get-ContainersFor([string]$ancestor) {
  docker ps -a --filter "ancestor=$ancestor" --format "{{.ID}}"
}

Write-Host "Starting image cleanup..." -ForegroundColor Cyan
if ($DryRun) { Write-Host "[DRY RUN] No changes will be made." -ForegroundColor Yellow }

foreach ($img in $images) {
  $id = Get-ImageId $img
  if (-not $id) {
    $notFound.Add($img)
    continue
  }

  $cids = Get-ContainersFor $id
  if ($cids) {
    if ($ForceRemoveContainers) {
      Write-Host "Removing containers for $img ..." -ForegroundColor Yellow
      if (-not $DryRun) {
        foreach ($cid in $cids) { docker rm -f $cid | Out-Null }
      } else {
        Write-Host "  [DRY RUN] Would remove containers: $($cids -join ', ')"
      }
    } else {
      $skipped.Add("$img (in use by containers: $($cids -join ', '))")
      continue
    }
  }

  Write-Host "Removing image $img ..." -ForegroundColor Cyan
  if (-not $DryRun) {
    try {
      docker rmi -f $id | Out-Null
      $removed.Add($img)
    } catch {
      $errors.Add("$img :: $($_.Exception.Message)")
    }
  } else {
    Write-Host "  [DRY RUN] Would remove image: $img"
  }
}

if ($PruneDangling -and -not $DryRun) {
  Write-Host "Pruning dangling images/layers..." -ForegroundColor Cyan
  docker image prune -f | Out-Null
}

Write-Host "`nSummary" -ForegroundColor Green
Write-Host "Removed:    $($removed.Count)"
$removed  | ForEach-Object { Write-Host "  - $_" }
Write-Host "Skipped:    $($skipped.Count)"
$skipped  | ForEach-Object { Write-Host "  - $_" }
Write-Host "Not found:  $($notFound.Count)"
$notFound | ForEach-Object { Write-Host "  - $_" }
Write-Host "Errors:     $($errors.Count)"
$errors   | ForEach-Object { Write-Host "  - $_" }

# Usage examples
# powershell -ExecutionPolicy Bypass -File .\scripts\remove-images.ps1 -DryRun
# powershell -ExecutionPolicy Bypass -File .\scripts\remove-images.ps1
# powershell -ExecutionPolicy Bypass -File .\scripts\remove-images.ps1 -ForceRemoveContainers
# powershell -ExecutionPolicy Bypass -File .\scripts\remove-images.ps1 -ForceRemoveContainers -PruneDangling
# powershell -ExecutionPolicy Bypass -File .\scripts\remove-images.ps1 -IncludeK8s -ForceRemoveContainers

