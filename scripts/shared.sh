#!/usr/bin/env bash

get_info() {
	local host port user
	local cmd=$(__current_pane_command)
	if __mosh_cmd "$cmd"; then
		cmd=$(echo "$cmd" | grep -E 'mosh' | sed -E 's/^.*mosh(-client)? //')
		IFS=' ' read -r host port user <<<$(__get_mosh_info "$cmd")
	elif __ssh_cmd "$cmd"; then
		cmd=$(echo "$cmd" | grep -E 'ssh' | sed -E 's/^.*ssh //')
		IFS=' ' read -r host port user <<<$(__get_ssh_info "$cmd")
	elif __containered_cmd "$cmd"; then
		cmd=$(echo "$cmd" | grep -E 'docker|podman' | sed -E 's/^[[:space:]]* //')
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

mosh_connected() {
	local cmd=$(__current_pane_command)
	__mosh_cmd "$cmd"
}

containered() {
	local cmd=$(__current_pane_command)
	__containered_cmd "$cmd"
}

__ssh_cmd() {
	[[ $1 =~ (^|^[[:space:]]*|/?)ssh[[:space:]] ]] || [[ $1 =~ (^|^[[:space:]]*|/?)sshpass[[:space:]] ]]
}

__mosh_cmd() {
	[[ $1 =~ (^|^[[:space:]]*|/?)mosh[[:space:]] ]] || [[ $1 =~ (^|^[[:space:]]*|/?)mosh-client[[:space:]] ]]
}

__containered_cmd() {
	[[ $1 =~ (^|^[[:space:]]*|/?)docker[[:space:]] ]] || [[ $1 =~ (^|^[[:space:]]*|/?)podman[[:space:]] ]]
}

__current_pane_command() {
	local ppid=$(tmux display-message -p "#{pane_pid}")
	local pid command cmd

	while [[ -n "$ppid" ]] ; do
		IFS=' ' read -r ppid pid command <<<$(ps a -o ppid=,pid=,command= | grep -E "^[[:space:]]*$ppid")
		[[ -z "$command" ]] && break
		# @hack in case of ProxyJump, ssh spawns a new ssh connection to jump host as child process
		# in that case, check if both parent and child processes are ssh, select parent one's cmd
		__ssh_cmd "$cmd" && __ssh_cmd "$command" && break
		ppid="$pid"
		cmd="$command"
	done

	echo "$cmd"
}

__get_ssh_info() {
	local cmd="$1"
	# Fetch configuration with given cmd
	# Depending of ssh version, configuration output may or may not contain `host` directive
	# Check both `host` and `hostname` for old ssh versions compatibility and prefer `host` if exists
	ssh -TGN $cmd 2>/dev/null | grep -E -e '^host(name)?[[:space:]]' -e '^port[[:space:]]' -e '^user[[:space:]]' | sort --unique --key 1,1.4 | cut -f 2 -d ' ' | xargs
}

__get_mosh_info() {
	local cmd="$1"

	# @see https://tldp.org/LDP/abs/html/parameter-substitution.html
	shopt -s extglob

	# @see https://github.com/mobile-shell/mosh/blob/1105d481bb9143dad43adf768f58da7b029fd39c/scripts/mosh.pl#L465
	# ip and port placed after pipe separator in cmd
	local ip port
	IFS=' ' read -r ip port <<<"${cmd#*|*([[:space:]])}"

	# Clean cmd from ip-port...
	cmd="${cmd%%*([[:space:]])|*}"
	# ...and sanitize from leading #
	cmd="${cmd##*-#*([[:space:]])}"

	# @TODO fetch target
	# here we may have a lot of variants of mosh's cmdline, like
	#   TARGET
	#   TARGET --port 60006
	#   --ssh /usr/bin/ssh -o User=root TARGET --port 60006
	#   TARGET --ssh /usr/bin/ssh -o User=root --port 60006
	#   --ssh /usr/bin/ssh -o User=root --port 60006 TARGET
	#   etc.
	# @warn the problem is - how to detect TARGET on any position inside cmdline
	# @note cmdline doesn't contain any quotes
	# @note mosh's flags may or may not contain '=' between flag's name and it's value
	# @note value of ssh flag also may or may not contain '=' in it's value
	local target
	# Remove target from cmd to prevent duplications
	cmd="${cmd//[[:space:]]$target[[:space:]]/ }"

	# @hack ssh has no long flags, so `--` means mosh's flag
	# @warn this must be changed if ssh would provide long flags
	local cmd_args ssh_options
	IFS='#' read -r -a cmd_args <<<"${cmd//--/#}"
	for arg in "${cmd_args[@]}"; do
		if [[ $arg =~ ^ssh ]]; then
			# Clean `ssh` flag name...
			ssh_options="${arg#ssh[[:space:]|=]}"
			# ...and ssh binary from arg
			ssh_options="${ssh_options#*[[:space:]]}"
		fi
	done

	local host user
	IFS=' ' read -r host _ user <<<$(__get_ssh_info "${ssh_options} ${target:-$ip}")
	echo "${host:-$ip} $port $user"
}

__get_container_info() {
	local cmd="$1"

	local container
	local runner=${cmd%% *}
	if [[ $cmd =~ ' --name' ]]; then
		container=$(echo ${cmd##* --name} | cut -f 1 -d ' ')
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
