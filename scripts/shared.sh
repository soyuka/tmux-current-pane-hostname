#!/usr/bin/env bash

get_tmux_option() {
	local option=$1
	local default_value=$2
	local option_value=$(tmux show-option -gqv "$option")
	[[ -z "$option_value" ]] && echo "$default_value" || echo "$option_value"
}

set_tmux_option() {
	local option=$1
	local value=$2
	tmux set-option -gq "$option" "$value"
}

get_info() {
	local host port user
	local cmd=$(_current_pane_command)
	if _ssh_cmd "$cmd"; then
		cmd=$(echo "$cmd" | grep -E 'ssh' | sed -E 's/^.*ssh //')
		read -r host port user <<<$(_get_remote_info "$cmd")
	elif _containered_cmd "$cmd"; then
		cmd=$(echo "$cmd" | grep -E 'docker|podman' | sed -E 's/^[[:blank:]]* //')
		read -r host user <<<$(_get_container_info "$cmd")
	else
		read -r host user <<<$(_get_local_info)
	fi
	#
	# Return requested info
	case "$1" in
		"user") # user from ssh info or `whoami`
			[[ -z "$user" ]] && _get_username || echo "$user"
			;;
		"host") # host from ssh info or `hostname`
			[[ -z "$host" ]] && _get_hostname || echo "$host"
			;;
		"host_short") # host from ssh info or `hostname -s`
			[[ -z "$host" ]] && _get_hostname_short || echo "$host"
			;;
		"port") # port from ssh info or empty
			echo "$port"
			;;
		*) # user from ssh info + "@host" if host is not empty + ":port" if port is not empty
			echo "${user}${host:+@$host}${port:+:$port}"
			;;
	esac
}

ssh_connected() {
	local cmd=$(_current_pane_command)
	_ssh_cmd "$cmd"
}

_ssh_cmd() {
	[[ $1 =~ (^|^[[:blank:]]*|/?)ssh[[:blank:]] ]] || [[ $1 =~ (^|^[[:blank:]]*|/?)sshpass[[:blank:]] ]]
}

containered() {
	local cmd=$(_current_pane_command)
	_containered_cmd "$cmd"
}

_containered_cmd() {
	[[ $1 =~ (^|^[[:blank:]]*|/?)docker[[:blank:]] ]] || [[ $1 =~ (^|^[[:blank:]]*|/?)podman[[:blank:]] ]]
}

_current_pane_command() {
	local ppid=$(tmux display-message -p "#{pane_pid}")
	local pid command cmd

	while [[ -n "$ppid" ]] ; do
		read -r ppid pid command <<<$(ps -o ppid=,pid=,command= | grep -E "^[[:blank:]]*$ppid")
		[[ -z "$command" ]] && break
		ppid="$pid"
		cmd="$command"
	done

	echo "$cmd"
}

_get_remote_info() {
	local cmd="$1"
	# Fetch configuration with given cmd
	ssh -G $cmd 2>/dev/null | grep -E -e '^hostname\s' -e '^port\s' -e '^user\s' | sort | cut -f 2 -d ' ' | xargs
}

_get_container_info() {
	local cmd="$1"

	local runner=${cmd%% *}
	if [[ $cmd =~ ' --name' ]]; then
		local container=$(echo ${cmd##* --name} | cut -f 1 -d ' ')
		container=${container##*=}
	else
		# @TODO get dynamic named container
		# local all_running_containers=$($runner ps -q | xargs $runner inspect)
		_get_local_info
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

_get_local_info() {
	local user=$(_get_username)
	local host=$(_get_hostname)

	echo "${host} ${user}"
}


_get_username() {
	command -v whoami > /dev/null && whoami
}

_get_hostname() {
	command -v hostname > /dev/null && hostname || echo "${HOSTNAME}"
}

_get_hostname_short() {
	command -v hostname > /dev/null && hostname --short || echo "${HOSTNAME%%.*}"
}
