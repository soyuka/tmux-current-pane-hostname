#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source $CURRENT_DIR/utils/tmux.sh
source $CURRENT_DIR/shared.sh

main() {
	local user host port
	IFS='#' read -r user host port <<< "$(get_info)"
	echo "${user}${host:+@$host}${port:+:$port}"

	# @TODO user-formatted pane_ssh_connect output
	# eval is literaly evil, so i won't use this
	# eval echo $(get_tmux_option $pane_ssh_connect_format)
	# get_tmux_option $pane_ssh_connect_format | sed \
	# 	-e "s/%{user}/$user/" \
	# 	-e "s/%{host}/$host/" \
	# 	-e "s/%{port}/$port/"
}

main
