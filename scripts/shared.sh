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

get_remote_info() {
	# First get the current pane command pid to get the full command with arguments
	local cmd=$(_current_pane_command | grep -E 'ssh' | sed -E 's/^[0-9]*[[:blank:]]*ssh //')
	# Fetch configuration with given cmd
	ssh -G $cmd 2>/dev/null | grep -E -e '^hostname\s' -e '^port\s' -e '^user\s' | sort | cut -f 2 -d ' ' | xargs
}

get_container_info() {
	local cmd=$(_current_pane_command | grep -E 'docker|podman' | sed -E 's/^[0-9]*[[:blank:]]* //')

	local runner=${cmd%% *}
	if [[ $cmd =~ ' --name' ]]; then
		local container=$(echo ${cmd##* --name} | cut -f 1 -d ' ')
		container=${container##*=}
	else
		# @TODO get dynamic named container
		# local all_running_containers=$($runner ps -q | xargs $runner inspect)
		return
	fi

	local info=$($runner inspect --format '{{ .Config.Hostname }}/{{ .Config.Domainname }}/{{ .Config.User }}' $container)
	local host=$(echo $info | cut -f 1 -d '/')
	local domain=$(echo $info | cut -f 2 -d '/')
	local user=$(echo $info | cut -f 3 -d '/')
	# @TODO `port` is not applicable with container for now
	echo "${host}${domain:+.$domain} 0 ${user}"
}

get_info() {
	local host port user
	# If command is ssh, fetch connection info
	if ssh_connected; then
		read -r host port user <<<$(get_remote_info)
	fi
	if containered; then
		read -r host port user <<<$(get_container_info)
	fi
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

	[[ $cmd =~ " ssh " ]] || [[ $cmd =~ " sshpass " ]]
}

containered() {
	local cmd=$(_current_pane_command)

	[[ $cmd =~ " docker " ]] || [[ $cmd =~ " podman " ]]
}

_current_pane_command() {
	local pane_pid=$(tmux display-message -p "#{pane_pid}")
	local pane_process_pid=$(pgrep -flaP $pane_pid | cut -f 1 -d ' ')

	ps -o command -p $pane_process_pid | grep -v 'COMMAND'
}

_get_username() {
	command -v whoami && whoami
}

_get_hostname() {
	command -v hostname && hostname || echo "${HOSTNAME}"
}

_get_hostname_short() {
	command -v hostname && hostname --short || echo "${HOSTNAME%%.*}"
}
