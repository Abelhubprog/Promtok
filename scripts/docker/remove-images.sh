#!/usr/bin/env bash
set -euo pipefail

# Env flags:
#   FORCE=1       # also remove containers using these images
#   PRUNE=1       # prune dangling images after removal
#   INCLUDE_K8S=1 # include Docker Desktop Kubernetes images
#   DRY=1         # dry run

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

if [[ "${INCLUDE_K8S:-0}" != "1" ]]; then
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

get_containers() { docker ps -a --filter "ancestor=$1" -q; }
has_image() { docker images --format "{{.Repository}}:{{.Tag}}" | grep -Fx "$1" >/dev/null 2>&1; }

echo "Starting image cleanup..."
[[ "${DRY:-0}" == "1" ]] && echo "[DRY RUN] No changes will be made."

for img in "${images[@]}"; do
  if ! has_image "$img"; then
    notfound+=("$img")
    continue
  fi

  cids=$(get_containers "$img") || true
  if [[ -n "$cids" && "${FORCE:-0}" != "1" ]]; then
    skipped+=("$img (in use by containers: $(echo "$cids" | tr '\n' ' ' | sed 's/ $//'))")
    continue
  fi

  if [[ -n "$cids" && "${FORCE:-0}" == "1" ]]; then
    echo "Removing containers for $img ..."
    if [[ "${DRY:-0}" != "1" ]]; then
      echo "$cids" | xargs -r docker rm -f >/dev/null
    else
      echo "  [DRY RUN] Would remove: $(echo "$cids" | tr '\n' ' ' | sed 's/ $//')"
    fi
  fi

  echo "Removing image $img ..."
  if [[ "${DRY:-0}" != "1" ]]; then
    if docker rmi -f "$img" >/dev/null 2>&1; then
      removed+=("$img")
    else
      errors+=("$img")
    fi
  else
    echo "  [DRY RUN] Would remove image: $img"
  fi
done

if [[ "${PRUNE:-0}" == "1" && "${DRY:-0}" != "1" ]]; then
  docker image prune -f >/dev/null
fi

echo
printf 'Removed:    %d\n' "${#removed[@]}"
for r in "${removed[@]}"; do printf '  - %s\n' "$r"; done
printf 'Skipped:    %d\n' "${#skipped[@]}"
for s in "${skipped[@]}"; do printf '  - %s\n' "$s"; done
printf 'Not found:  %d\n' "${#notfound[@]}"
for n in "${notfound[@]}"; do printf '  - %s\n' "$n"; done
printf 'Errors:     %d\n' "${#errors[@]}"
for e in "${errors[@]}"; do printf '  - %s\n' "$e"; done
