#!/bin/bash

# PROMTOK Direct CLI Helper Script
# This script provides direct document processing with live feedback

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

check_docker_compose() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed or not in PATH"; exit 1; fi
    if ! docker compose version &> /dev/null; then
        print_error "Docker Compose is not available"; exit 1; fi
}

ensure_backend_running() {
    print_info "Checking if backend is running..."
    if ! docker compose ps backend | grep -q "Up"; then
        print_info "Starting backend service..."; docker compose up -d backend; sleep 5; fi
}

run_direct_cli() {
    check_docker_compose; ensure_backend_running
    docker compose --profile cli run --rm cli python cli_ingest.py "$@"
}

show_help() {
    cat << 'EOF'
PROMTOK Direct CLI Helper Script

This tool provides DIRECT document processing with live feedback, bypassing the background queue.
Documents are processed synchronously with real-time progress updates.

Usage: ./promtok-cli.sh <command> [options]

Commands:
  create-user <username> <password> [--full-name "Name"] [--admin]
  create-group <username> <group_name> [--description "Description"]
  list-groups [--user <username>]
  ingest <username> <document_directory> [--group <group_id>] [--force-reembed] [--device <device>] [--delete-after-success] [--batch-size <num>]
  status [--user <username>] [--group <group_id>]
  cleanup [--user <username>] [--status <status>] [--group <group_id>] [--confirm]
  cleanup-cli [--dry-run] [--force]
  search <username> <query> [--limit <num>]
  reset-db [--backup] [--force] [--stats] [--check]

Examples:
  ./promtok-cli.sh create-user researcher mypass123 --full-name "Research User"
  ./promtok-cli.sh ingest researcher ./documents --batch-size 5
  ./promtok-cli.sh status --user researcher
  ./promtok-cli.sh cleanup --status failed --confirm
EOF
}

case "$1" in
  create-user|create-group|list-groups|ingest|status|cleanup|cleanup-cli|search|reset-db)
    shift; run_direct_cli "$@" ;;
  help|--help|-h|"")
    show_help ;;
  *)
    print_error "Unknown command: $1"; show_help; exit 1 ;;
esac

