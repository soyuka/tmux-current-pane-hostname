#!/usr/bin/env bash

# @TODO user-formatted pane_ssh_connect output
declare -r pane_ssh_connect_format='@pane-ssh-connect-format'

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

