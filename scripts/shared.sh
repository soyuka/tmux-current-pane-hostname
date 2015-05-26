#!/usr/bin/env bash

get_tmux_option() {
	local option=$1
	local default_value=$2
	local option_value=$(tmux show-option -gqv "$option")
	if [ -z "$option_value" ]; then
		echo $default_value
	else
		echo $option_value
	fi
}

set_tmux_option() {
	local option=$1
	local value=$2
	tmux set-option -gq "$option" "$value"
}

parse_ssh_port() {
  # If there is a port get it
  local port=$(echo $1|grep -Eo '\-p ([0-9]+)'|sed 's/-p //')

  if [ -z $port ]; then
    local port=22
  fi

  echo $port
}

get_remote_info() {
  local command=$1

  # First get the current pane command pid to get the full command with arguments
  local cmd=$(pgrep -flP `tmux display-message -p "#{pane_pid}"` | sed -E 's/^[0-9]+ ssh //')

  local port=$(parse_ssh_port "$cmd")

  local cmd=$(echo $cmd|sed 's/\-p '"$port"'//g')

  local user=$(echo $cmd | awk '{print $NF}'|cut -f1 -d@)
  local host=$(echo $cmd | awk '{print $NF}'|cut -f2 -d@)

  if [ $user == $host ]; then
    local user=$(whoami)
  fi

  case "$1" in
    "whoami")
      echo $user
      ;;
    "hostname")
      echo $host
      ;;
    *)
      echo "$user@$host:$port"
      ;;
  esac
}

get_info() {
  # Get current pane command
  local cmd=$(tmux display-message -p "#{pane_current_command}")

  # If command is ssh do some magic
  if [ $cmd = "ssh" ]; then
    echo $(get_remote_info $1)
  else
    echo $($1)
  fi
}
