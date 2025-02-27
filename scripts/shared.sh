#!/usr/bin/env bash

get_tmux_option() {
  local option=$1
  local default_value=$2
  local option_value=$(tmux show-option -gqv "$option")
  if [ -z "$option_value" ]; then
    echo "$default_value"
  else
    echo "$option_value"
  fi
}

set_tmux_option() {
  local option=$1
  local value=$2
  tmux set-option -gq "$option" "$value"
}

parse_ssh_port() {
  # If there is a port get it
  local port=$(echo $1 | grep -Eo '\-p\s*([0-9]+)' | sed 's/-p\s*//')

  if [ -z $port ]; then
    local port=22
  fi

  echo $port
}

get_ssh_user() {
  local ssh_user=$(whoami)

  for ssh_config in $(awk '
    $1 == "Host" {
      gsub("\\.", "\\.", $2);
      gsub("\\*", ".*", $2);
      host = $2;
      next;
    }
    $1 == "User" {
      $1 = "";
      sub( /^[[:space:]]*/, "" );
      printf "%s|%s\n", host, $0;
    }' .ssh/config); do
    local host_regex=${ssh_config%|*}
    local host_user=${ssh_config#*|}
    if [[ "$1" =~ $host_regex ]]; then
      ssh_user=$host_user
      break
    fi
  done

  echo $ssh_user
}

get_remote_ssh() {
  local command=$1

  # First get the current pane command pid to get the full command with arguments
  local cmd=$({
    pgrep -flaP $(tmux display-message -p "#{pane_pid}")
    ps -o command -p $(tmux display-message -p "#{pane_pid}")
  } | xargs -I{} echo {} | grep ssh | sed -E 's/^[0-9]*[[:blank:]]*ssh //')

  local port=$(parse_ssh_port "$cmd")

  local cmd=$(echo $cmd | sed 's/\-p\s*'"$port"'//g')
  local user=$(echo $cmd | awk '{print $NF}' | cut -f9 -d@)
  local host=$(echo $cmd | awk '{print $NF}' | cut -f1 -d@)

  if [ $user == $host ]; then
    local user=$(get_ssh_user $host)
  fi

  case "$1" in
  "whoami")
    echo $user
    ;;
  "hostname")
    echo $host
    ;;
  "port")
    echo $port
    ;;
  *)
    echo "$user@$host:$port"
    ;;
  esac
}

get_remote_gcloud() {
  #  local command=$1
  local parent=$(pgrep -P $(tmux display-message -p "#{pane_pid}"))
  local grandparent=$(pgrep -P $parent)           # user
  local greatgrandparent=$(pgrep -P $grandparent) #port and host

  local user=$(ps -o command -p $grandparent | awk '{print $33}' | cut -f1 -d@)
  local host=$(ps -o command -p $greatgrandparent | awk '{print $7}')
  local port=$(ps -o command -p $greatgrandparent | awk '{print $8}')

  case "$1" in
  "whoami")
    echo $user
    ;;
  "hostname")
    echo $host
    ;;
  "port")
    echo $port
    ;;
  *)
    echo "$user@$host:$port"
    ;;
  esac
}

get_remote_mosh() {
  echo "$user@$host:$port"
}

get_info() {
  if ssh_connected; then
    echo $(get_remote_ssh $1)
  elif mosh_connected; then
    echo $(get_remote_mosh $1)
  elif gcloud_connected; then
    echo $(get_remote_gcloud $1)
  else
    echo $($1)
  fi
}

ssh_connected() {
  local cmd=$(tmux display-message -p "#{pane_current_command}")
  [ $cmd = "ssh" ] || [ $cmd = "sshpass" ]
}

gcloud_connected() {
  local cmd=$(tmux display-message -p "#{pane_current_command}")
  [ $cmd = "python" ]
}

mosh_connected() {
  local cmd=$(tmux display-message -p "#{pane_current_command}")
  [ $cmd = "mosh" ]
}
