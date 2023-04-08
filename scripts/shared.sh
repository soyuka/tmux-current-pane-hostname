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
	local command=$1
	local pane_pid=$(tmux display-message -p "#{pane_pid}")

	# First get the current pane command pid to get the full command with arguments
	local cmd=$({ pgrep -flaP $pane_pid ; ps -o command -p $pane_pid ; } | xargs -I{} echo {} | grep ssh | sed -E 's/^[0-9]*[[:blank:]]*ssh //')
	# Fetch configuration with given cmd
	ssh -G $cmd 2>/dev/null | grep -E -e '^host\s' -e '^port\s' -e '^user\s' | sort | cut -f 2 -d ' ' | xargs
}

get_info() {
	# If command is ssh, fetch connection info
	if ssh_connected; then
		read -r host port user <<<$(get_remote_info)
	fi
	# Return requested info
	case "$1" in
		"user") # user from ssh info or `whoami`
			[[ -z "$user" ]] && whoami || echo "$user"
			;;
		"host") # host from ssh info or `hostname`
			[[ -z "$host" ]] && hostname || echo "$host"
			;;
		"host_short") # host from ssh info or `hostname -s`
			[[ -z "$host" ]] && hostname -s || echo "$host"
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
	local pane_pid=$(tmux display-message -p "#{pane_pid}")

	# Get current pane command
	local cmd=$(pgrep -flaP $pane_pid)

	[[ $cmd =~ " ssh " ]] || [[ $cmd =~ " sshpass " ]]
}
