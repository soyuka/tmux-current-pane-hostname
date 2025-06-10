#!/usr/bin/env bash

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

__current_pane_command() {
	local ppid=$(tmux display-message -p "#{pane_pid}")
	local pid command cmd

	while [[ -n "$ppid" ]] ; do
		IFS=' ' read -r ppid pid command <<<$(ps a -o ppid=,pid=,command= | grep -E "^[[:blank:]]*$ppid")
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
