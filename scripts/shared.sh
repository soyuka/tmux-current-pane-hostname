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

get_info() {
	local host port user
	local cmd=$(__current_pane_command)
	if __ssh_cmd "$cmd"; then
		cmd=$(echo "$cmd" | grep -E 'ssh' | sed -E 's/^.*ssh //')
		IFS=' ' read -r host port user <<<$(__get_remote_info "$cmd")
	elif __containered_cmd "$cmd"; then
		cmd=$(echo "$cmd" | grep -E 'docker|podman' | sed -E 's/^[[:blank:]]* //')
		IFS=' ' read -r host user <<<$(__get_container_info "$cmd")
	else
		IFS=' ' read -r host user <<<$(__get_local_info)
	fi
	# Set defaults
	user="${user:-$(__get_username)}"
	host="${host:-$(__get_hostname)}"

	# Return requested info
	case "$1" in
		"user")
			echo "$user"
			;;
		"host")
			echo "$host"
			;;
		"host_short")
			[[ -z "$host" ]] && __get_hostname_short || echo "$host"
			;;
		"port")
			echo "$port"
			;;
		*)
			echo "${user}#${host}#${port}"
			;;
	esac
}

ssh_connected() {
	local cmd=$(__current_pane_command)
	__ssh_cmd "$cmd"
}

containered() {
	local cmd=$(__current_pane_command)
	__containered_cmd "$cmd"
}


__ssh_cmd() {
	[[ $1 =~ (^|^[[:blank:]]*|/?)ssh[[:blank:]] ]] || [[ $1 =~ (^|^[[:blank:]]*|/?)sshpass[[:blank:]] ]]
}

__containered_cmd() {
	[[ $1 =~ (^|^[[:blank:]]*|/?)docker[[:blank:]] ]] || [[ $1 =~ (^|^[[:blank:]]*|/?)podman[[:blank:]] ]]
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
  local pane_pid=$(tmux display-message -p "#{pane_pid}")
  local parent=$(pgrep -P $pane_pid)
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
  local pane_pid=$(tmux display-message -p "#{pane_pid}")
  local parent=$(pgrep -P $pane_pid)

  local user=$(ps -o command -p $parent | awk '{print $3}' | cut -f1 -d@)
  local host=$(ps -o command -p $parent | awk '{print $3}' | cut -f2 -d@)
  local port=$(ps -o command -p $parent | awk '{print $6}')
  local ip=$(ps -o command -p $parent | awk '{print $5}')

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
  "ip")
    echo $ip
    ;;
  *)
    echo "$user@$host:$port"
    ;;
  esac
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
=======
__current_pane_command() {
	local ppid=$(tmux display-message -p "#{pane_pid}")
	local pid command cmd

	while [[ -n "$ppid" ]] ; do
		IFS=' ' read -r ppid pid command <<<$(ps -o ppid=,pid=,command= | grep -E "^[[:blank:]]*$ppid")
		[[ -z "$command" ]] && break
		# @hack in case of ProxyJump, ssh spawns a new ssh connection to jump host as child process
		# in that case, check if both parent and child processes are ssh, select parent one's cmd
		__ssh_cmd "$cmd" && __ssh_cmd "$command" && break
		ppid="$pid"
		cmd="$command"
	done

	echo "$cmd"
}

__get_remote_info() {
	local cmd="$1"
	# Fetch configuration with given cmd
	# Depending of ssh version, configuration output may or may not contain `host` directive
	# Check both `host` and `hostname` for old ssh versions compatibility and prefer `host` if exists
	ssh -TGN $cmd 2>/dev/null | grep -E -e '^host(name)?\s' -e '^port\s' -e '^user\s' | sort --unique --key 1,1.4 | cut -f 2 -d ' ' | xargs
}

__get_container_info() {
	local cmd="$1"

	local runner=${cmd%% *}
	if [[ $cmd =~ ' --name' ]]; then
		local container=$(echo ${cmd##* --name} | cut -f 1 -d ' ')
		container=${container##*=}
	else
		# @TODO get dynamic named container
		# local all_running_containers=$($runner ps -q | xargs $runner inspect)
		__get_local_info
		return
	fi

	local format
	case $runner in
		'docker')
			format='{{ .Config.Hostname }}/{{ .Config.Domainname }}/{{ .Config.User }}'
			;;
		'podman')
			format='{{ .Config.Hostname }}/{{ .Config.DomainName }}/{{ .Config.User }}'
			;;
	esac

	local info=$($runner inspect --format "$format" "$container")
	local host=$(echo $info | cut -f 1 -d '/')
	local domain=$(echo $info | cut -f 2 -d '/')
	local user=$(echo $info | cut -f 3 -d '/')

	echo "${host}${domain:+.$domain} ${user}"
}

__get_local_info() {
	local user=$(__get_username)
	local host=$(__get_hostname)

	echo "${host} ${user}"
}

__get_username() {
	command -v whoami > /dev/null && whoami
}

__get_hostname() {
	command -v hostname > /dev/null && hostname || echo "${HOSTNAME}"
}

__get_hostname_short() {
	command -v hostname > /dev/null && hostname --short || echo "${HOSTNAME%%.*}"
}

gcloud_connected() {
  local cmd=$(tmux display-message -p "#{pane_current_command}")
  [ $cmd = "python" ]
}

mosh_connected() {
  local cmd=$(tmux display-message -p "#{pane_current_command}")
  [ $cmd = "mosh-client" ]
}
