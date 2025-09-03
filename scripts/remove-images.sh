#!/usr/bin/env bash
set -euo pipefail

# Flags via env vars
# FORCE=1 to remove containers using images
# PRUNE=1 to prune dangling layers
# INCLUDE_K8S=1 to include Kubernetes images
# DRY=1 for dry run

FORCE="${FORCE:-0}"
PRUNE="${PRUNE:-0}"
INCLUDE_K8S="${INCLUDE_K8S:-0}"
DRY="${DRY:-0}"

images=(
  "maestro-frontend:latest"
  "maestro-nginx:latest"
  "welcome-to-docker:latest"
  "ghcr.io/github/github-mcp-server:latest"
  "pgvector/pgvector:pg15"
  "mongo:6"
  "redis:alpine"
  "redis:7-alpine"
  "postgres:latest"
  "drewsk/docker-sql-extension:0.3.0"

  # K8s / Desktop
  "docker/desktop-kubernetes:kubernetes-v1.32.2-cni-v1.6.0-critools-v1.31.1-cri-dockerd-v0.3.16-1-debian"
  "registry.k8s.io/kube-apiserver:v1.32.2"
  "registry.k8s.io/kube-controller-manager:v1.32.2"
  "registry.k8s.io/kube-scheduler:v1.32.2"
  "registry.k8s.io/kube-proxy:v1.32.2"
  "registry.k8s.io/etcd:3.5.16-0"
  "registry.k8s.io/coredns/coredns:v1.11.3"
  "registry.k8s.io/pause:3.10"

  # Desktop extensions/system
  "grafana/docker-desktop-extension:2.0.0"
  "docker/desktop-vpnkit-controller:dc331cb22850be0cdd97c84a9cfecaf44a1afb6e"
  "docker/desktop-storage-provisioner:v2.0"

  # Others
  "langchain/langchain:latest"
  "docker/welcome-to-docker:latest"
  "virag/redis-enterprise-docker-extension:0.1.0"
)

if [[ "$INCLUDE_K8S" != "1" ]]; then
  filtered=()
  for img in "${images[@]}"; do
    if [[ "$img" =~ ^docker/desktop-kubernetes: ]] || [[ "$img" =~ ^registry\.k8s\.io/ ]]; then
      continue
    fi
    filtered+=("$img")
  done
  images=("${filtered[@]}")
fi

removed=()
skipped=()
notfound=()
errors=()

has_image() {
  docker images --format "{{.Repository}}:{{.Tag}}" | grep -Fx "$1" >/dev/null 2>&1
}

image_id_for() {
  docker images --format "{{.Repository}}:{{.Tag}} {{.ID}}" | awk -v ref="$1 " 'index($0, ref)==1 { print $2; exit }'
}

containers_for() {
  docker ps -a --filter "ancestor=$1" -q
}

echo "Starting image cleanup..."
if [[ "$DRY" == "1" ]]; then echo "[DRY RUN] No changes will be made."; fi

for img in "${images[@]}"; do
  if ! has_image "$img"; then
    notfound+=("$img")
    continue
  fi

  id="$(image_id_for "$img")"
  cids="$(containers_for "$id")" || cids=""

  if [[ -n "$cids" && "$FORCE" != "1" ]]; then
    skipped+=("$img (in use by containers: $(echo "$cids" | tr '\n' ' ' | sed 's/ $//'))")
    continue
  fi

  if [[ -n "$cids" && "$FORCE" == "1" ]]; then
    echo "Removing containers for $img ..."
    if [[ "$DRY" != "1" ]]; then
      echo "$cids" | xargs -r docker rm -f >/dev/null
    else
      echo "  [DRY RUN] Would remove: $(echo "$cids" | tr '\n' ' ' | sed 's/ $//')"
    fi
  fi

  echo "Removing image $img ..."
  if [[ "$DRY" != "1" ]]; then
    if docker rmi -f "$id" >/dev/null 2>&1; then
      removed+=("$img")
    else
      errors+=("$img")
    fi
  else
    echo "  [DRY RUN] Would remove image: $img"
  fi
done

if [[ "$PRUNE" == "1" && "$DRY" != "1" ]]; then
  docker image prune -f >/dev/null
fi

echo
echo "Removed:    ${#removed[@]}"; printf '  - %s\n' "${removed[@]}" 2>/dev/null || true
echo "Skipped:    ${#skipped[@]}"; printf '  - %s\n' "${skipped[@]}" 2>/dev/null || true
echo "Not found:  ${#notfound[@]}"; printf '  - %s\n' "${notfound[@]}" 2>/dev/null || true
echo "Errors:     ${#errors[@]}"; printf '  - %s\n' "${errors[@]}" 2>/dev/null || true

# Examples
# DRY=1 bash scripts/remove-images.sh
# bash scripts/remove-images.sh
# FORCE=1 PRUNE=1 bash scripts/remove-images.sh
# INCLUDE_K8S=1 FORCE=1 PRUNE=1 bash scripts/remove-images.sh

