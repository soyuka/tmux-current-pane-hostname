#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source $CURRENT_DIR/shared.sh

main() {
  if ssh_connected; then
    echo "SSH"
  elif gcloud_connected; then
    echo "GC"
  elif mosh_connected; then
    echo "MOSH"
  else
    echo ""
  fi
}

main
