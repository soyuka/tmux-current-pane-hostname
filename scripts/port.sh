#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source $CURRENT_DIR/shared.sh

main() {

  if ssh_connected; then
    get_info "port"
  elif gcloud_connected; then
    get_info "port"
  elif mosh_connected; then
    get_info "port"
  fi

}

main
